import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { basename, dirname, extname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import {
  binaryFromPreferences,
  ConsoleOperations,
  type OperationsHost,
  type RuntimeSettings,
  type WorkspaceInfo,
} from "../../plugin/math-coding-console/server/core/operations";
import { rpcSchemas } from "../../plugin/math-coding-console/shared/schemas";
import { SettingsStore, defaultSettingsPath } from "./settings-store";

/**
 * The local console server.
 *
 * It serves the same contracts the Paseo plugin serves, over HTTP, to a page
 * that runs in a plain browser. The operations are the shared ones: this file
 * only resolves the workspace, validates the traffic and hands the bytes over.
 *
 * The project the console reads is fixed when the server starts. A request
 * never names a path.
 */

const MAX_BODY_BYTES = 1_048_576;

const CONTENT_TYPES: Record<string, string> = {
  ".css": "text/css; charset=utf-8",
  ".gif": "image/gif",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".map": "application/json; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
  ".txt": "text/plain; charset=utf-8",
  ".webp": "image/webp",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
};

export interface ConsoleServerOptions {
  /** The project the console reads. It is fixed when the server starts. */
  root: string;
  /** The port to listen on. Zero picks a free one. */
  port?: number;
  /** Where the preferences live. They never live inside the project. */
  settingsPath?: string;
  /** The built page. */
  dist?: string;
}

export interface ConsoleServerHandle {
  readonly url: string;
  readonly port: number;
  readonly root: string;
  close(): Promise<void>;
}

interface RequestContext {
  readonly root: string;
  port: number;
  readonly operations: ConsoleOperations;
  readonly host: OperationsHost;
  readonly settings: SettingsStore;
  readonly dist: string;
}

/** The workspace of the local console: the project the server was started for. */
class LocalOperationsHost implements OperationsHost {
  constructor(private readonly root: string, private readonly settings: SettingsStore) {}

  async resolveWorkspace(workspaceId: string): Promise<WorkspaceInfo> {
    return { id: workspaceId, name: basename(this.root) || null, directory: this.root };
  }

  async resolveRuntime(): Promise<RuntimeSettings> {
    const values = await this.settings.values();
    return { binary: binaryFromPreferences(values), allowRunChecks: values.allowRunChecks };
  }
}

function defaultDist(): string {
  return resolve(dirname(fileURLToPath(import.meta.url)), "..", "dist");
}

function sendJson(response: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload),
    "Cache-Control": "no-store",
  });
  response.end(payload);
}

function sendError(response: ServerResponse, status: number, error: string): void {
  sendJson(response, status, { error });
}

function sendText(response: ServerResponse, status: number, body: string, contentType: string): void {
  response.writeHead(status, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  response.end(body);
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** The server speaks to itself only. A foreign host is a foreign caller. */
function allowedHost(header: string | undefined): boolean {
  if (!header) return false;
  const host = header.trim().toLowerCase().replace(/:\d+$/, "");
  return host === "127.0.0.1" || host === "localhost";
}

/** A browser may only post from the page the server itself served. */
function allowedOrigin(origin: string | undefined, port: number): boolean {
  if (origin === undefined) return true;
  let url: URL;
  try {
    url = new URL(origin);
  } catch {
    return false;
  }
  if (url.protocol !== "http:") return false;
  const host = url.hostname.toLowerCase();
  if (host !== "127.0.0.1" && host !== "localhost") return false;
  return url.port === String(port);
}

async function readBody(request: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk));
    size += buffer.length;
    if (size > MAX_BODY_BYTES) throw new Error("The request body is too large");
    chunks.push(buffer);
  }
  return Buffer.concat(chunks).toString("utf8");
}

function isJson(contentType: string | undefined): boolean {
  if (!contentType) return false;
  return contentType.split(";")[0]?.trim().toLowerCase() === "application/json";
}

function issueText(error: { issues: readonly { path: readonly PropertyKey[]; message: string }[] }): string {
  return error.issues
    .slice(0, 5)
    .map((issue) => `${issue.path.map((part) => String(part)).join(".") || "input"}: ${issue.message}`)
    .join("; ");
}

function statusFor(error: unknown): number {
  const message = messageOf(error);
  if (message.includes("busy")) return 409;
  // A path the human asked for that the workspace does not allow is a mistake
  // in the request, not a failure of the server.
  if (message.includes("workspace") || message.includes("must be relative") ||
      message.includes("null byte") || message.includes("A path is required") ||
      message.includes("does not exist") || message.includes("Only a regular file")) {
    return 400;
  }
  return 500;
}

const PLACEHOLDER_PAGE = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Math Coding console</title>
    <style>
      body { font: 15px/1.5 system-ui, sans-serif; margin: 0; padding: 48px; color: #14181f; background: #ffffff; }
      code { background: #f5f6f8; border: 1px solid #d5dae1; border-radius: 4px; padding: 1px 5px; }
    </style>
  </head>
  <body>
    <main>
      <h1>Math Coding console</h1>
      <p>The page is not built yet.</p>
      <p>Run <code>npm run build</code> in the <code>console</code> directory, then reload this page.</p>
    </main>
  </body>
</html>
`;

async function serveStatic(context: RequestContext, pathname: string, response: ServerResponse): Promise<void> {
  const indexPath = join(context.dist, "index.html");
  try {
    await stat(indexPath);
  } catch {
    if (pathname === "/") {
      sendText(response, 200, PLACEHOLDER_PAGE, "text/html; charset=utf-8");
      return;
    }
    sendError(response, 404, "Not found");
    return;
  }
  const relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  const target = resolve(context.dist, relative);
  if (target !== context.dist && !target.startsWith(context.dist + sep)) {
    sendError(response, 404, "Not found");
    return;
  }
  try {
    const content = await readFile(target);
    const contentType = CONTENT_TYPES[extname(target).toLowerCase()] ?? "application/octet-stream";
    response.writeHead(200, {
      "Content-Type": contentType,
      "Content-Length": content.byteLength,
      "Cache-Control": "no-store",
    });
    response.end(content);
  } catch {
    sendError(response, 404, "Not found");
  }
}

async function handleRpc(
  context: RequestContext,
  name: string,
  body: unknown,
  response: ServerResponse,
): Promise<void> {
  try {
    if (name === "mathcoding.snapshot") {
      const input = rpcSchemas.snapshot.input.safeParse(body);
      if (!input.success) {
        sendError(response, 400, issueText(input.error));
        return;
      }
      const result = await context.operations.snapshot(context.host, input.data.workspaceId);
      const output = rpcSchemas.snapshot.output.safeParse(result);
      if (!output.success) {
        sendError(response, 500, `The snapshot does not match its contract: ${issueText(output.error)}`);
        return;
      }
      sendJson(response, 200, output.data);
      return;
    }
    if (name === "mathcoding.claim") {
      const input = rpcSchemas.claim.input.safeParse(body);
      if (!input.success) {
        sendError(response, 400, issueText(input.error));
        return;
      }
      const result = await context.operations.claimDetail(context.host, input.data);
      const output = rpcSchemas.claim.output.safeParse(result);
      if (!output.success) {
        sendError(response, 500, `The claim page does not match its contract: ${issueText(output.error)}`);
        return;
      }
      sendJson(response, 200, output.data);
      return;
    }
    if (name === "mathcoding.evidence") {
      const input = rpcSchemas.evidence.input.safeParse(body);
      if (!input.success) {
        sendError(response, 400, issueText(input.error));
        return;
      }
      const result = await context.operations.evidence(context.host, input.data);
      const output = rpcSchemas.evidence.output.safeParse(result);
      if (!output.success) {
        sendError(response, 500, `The evidence page does not match its contract: ${issueText(output.error)}`);
        return;
      }
      sendJson(response, 200, output.data);
      return;
    }
    if (name === "mathcoding.run") {
      const input = rpcSchemas.run.input.safeParse(body);
      if (!input.success) {
        sendError(response, 400, issueText(input.error));
        return;
      }
      const result = await context.operations.run(context.host, input.data);
      const output = rpcSchemas.run.output.safeParse(result);
      if (!output.success) {
        sendError(response, 500, `The run result does not match its contract: ${issueText(output.error)}`);
        return;
      }
      sendJson(response, 200, output.data);
      return;
    }
    if (name === "mathcoding.file") {
      const input = rpcSchemas.file.input.safeParse(body);
      if (!input.success) {
        sendError(response, 400, issueText(input.error));
        return;
      }
      const result = await context.operations.filePreview(context.host, input.data);
      const output = rpcSchemas.file.output.safeParse(result);
      if (!output.success) {
        sendError(response, 500, `The file preview does not match its contract: ${issueText(output.error)}`);
        return;
      }
      sendJson(response, 200, output.data);
      return;
    }
    sendError(response, 404, `Unknown endpoint: ${name}`);
  } catch (error) {
    sendError(response, statusFor(error), messageOf(error));
  }
}

async function handleApi(
  context: RequestContext,
  pathname: string,
  body: unknown,
  response: ServerResponse,
): Promise<void> {
  if (pathname.startsWith("/api/mathcoding.")) {
    await handleRpc(context, pathname.slice("/api/".length), body, response);
    return;
  }
  if (pathname === "/api/settings") {
    if (body === undefined) {
      const result = await context.settings.read();
      sendJson(response, 200, result);
      return;
    }
    const payload = body as { revision?: unknown; values?: unknown };
    if (typeof payload.revision !== "string" || payload.values === undefined) {
      sendJson(response, 200, { status: "invalid", error: "A revision and values are required" });
      return;
    }
    const result = await context.settings.write(payload.revision, payload.values);
    sendJson(response, 200, result);
    return;
  }
  if (pathname === "/api/settings/reset") {
    const result = await context.settings.reset();
    sendJson(response, 200, result);
    return;
  }
  sendError(response, 404, `Unknown endpoint: ${pathname}`);
}

async function handleRequest(
  context: RequestContext,
  request: IncomingMessage,
  response: ServerResponse,
): Promise<void> {
  const method = request.method ?? "GET";
  if (!allowedHost(request.headers.host)) {
    sendError(response, 403, "This console only serves the local machine");
    return;
  }
  if (method === "POST" && !allowedOrigin(request.headers.origin, context.port)) {
    sendError(response, 403, "This console only accepts requests from its own page");
    return;
  }
  const pathname = new URL(request.url ?? "/", "http://127.0.0.1").pathname;
  if (!pathname.startsWith("/api/")) {
    if (method === "GET" || method === "HEAD") {
      await serveStatic(context, pathname, response);
      return;
    }
    sendError(response, 404, "Not found");
    return;
  }
  if (method !== "POST" && method !== "GET") {
    sendError(response, 404, "Not found");
    return;
  }
  let body: unknown = undefined;
  if (method === "POST") {
    if (!isJson(request.headers["content-type"])) {
      sendError(response, 400, "POST requests must use the application/json content type");
      return;
    }
    const text = await readBody(request);
    if (text.trim() === "") {
      body = {};
    } else {
      try {
        body = JSON.parse(text) as unknown;
      } catch (error) {
        sendError(response, 400, `The request body is not valid JSON: ${messageOf(error)}`);
        return;
      }
    }
  }
  try {
    await handleApi(context, pathname, body, response);
  } catch (error) {
    sendError(response, statusFor(error), messageOf(error));
  }
}

export async function startConsoleServer(options: ConsoleServerOptions): Promise<ConsoleServerHandle> {
  const root = resolve(options.root);
  const settings = new SettingsStore(options.settingsPath ?? defaultSettingsPath());
  const operations = new ConsoleOperations();
  const context: RequestContext = {
    root,
    port: 0,
    operations,
    host: new LocalOperationsHost(root, settings),
    settings,
    dist: resolve(options.dist ?? defaultDist()),
  };
  const server = createServer((request, response) => {
    void handleRequest(context, request, response).catch((error: unknown) => {
      if (!response.headersSent) sendError(response, statusFor(error), messageOf(error));
      else response.end();
    });
  });
  await new Promise<void>((resolveListen, rejectListen) => {
    const onError = (error: Error) => rejectListen(error);
    server.once("error", onError);
    server.listen(options.port ?? 0, "127.0.0.1", () => {
      server.off("error", onError);
      resolveListen();
    });
  });
  const address = server.address();
  const port = typeof address === "object" && address !== null ? address.port : 0;
  context.port = port;
  return {
    url: `http://127.0.0.1:${String(port)}/`,
    port,
    root,
    close: () =>
      new Promise<void>((resolveClose) => {
        server.close(() => resolveClose());
        server.closeAllConnections?.();
      }),
  };
}

interface CliOptions {
  port?: number;
  root?: string;
  help: boolean;
}

export function parseArguments(argv: readonly string[]): CliOptions {
  const options: CliOptions = { help: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index] ?? "";
    const [name, inlineValue] = argument.startsWith("--") && argument.includes("=")
      ? [argument.slice(0, argument.indexOf("=")), argument.slice(argument.indexOf("=") + 1)]
      : [argument, undefined];
    const value = inlineValue ?? (name === "--port" || name === "--root" ? argv[++index] : undefined);
    if (name === "--help" || name === "-h") options.help = true;
    else if (name === "--port") options.port = Number(value);
    else if (name === "--root") options.root = value;
    else throw new Error(`Unknown argument: ${argument}`);
  }
  if (options.port !== undefined && (!Number.isInteger(options.port) || options.port < 0 || options.port > 65535)) {
    throw new Error("--port must be a port number between 0 and 65535");
  }
  if (options.root !== undefined && options.root.trim() === "") {
    throw new Error("--root must name a directory");
  }
  return options;
}

const USAGE = `Math Coding console

  npm run serve -- [--port PORT] [--root DIRECTORY]

  --port  The port to listen on. MATHC_CONSOLE_PORT is used when it is absent.
          Zero picks a free port.
  --root  The project the console reads. The current directory is used when it
          is absent. The project is fixed when the server starts.
`;

async function main(): Promise<void> {
  let options: CliOptions;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${messageOf(error)}\n\n${USAGE}`);
    process.exitCode = 2;
    return;
  }
  if (options.help) {
    process.stdout.write(USAGE);
    return;
  }
  const port = options.port ?? Number(process.env.MATHC_CONSOLE_PORT ?? "0");
  const root = resolve(options.root ?? process.cwd());
  const handle = await startConsoleServer({
    root,
    port: Number.isInteger(port) && port >= 0 && port <= 65535 ? port : 0,
  });
  process.stdout.write(`Math Coding console: ${handle.url}\n`);
  const stop = () => {
    void handle.close().then(() => process.exit(0));
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
}

const entry = process.argv[1] ? resolve(process.argv[1]) : "";
if (entry !== "" && entry === fileURLToPath(import.meta.url)) {
  void main().catch((error: unknown) => {
    process.stderr.write(`${messageOf(error)}\n`);
    process.exitCode = 1;
  });
}
