/**
 * The small helpers of the answers of the local server.
 *
 * The page and the settings store both read JSON answers and the code of an
 * error out of them, so the helpers live in one place instead of twice.
 */

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (text.trim() === "") return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

export function serverError(body: unknown, fallback: string): string {
  if (typeof body === "object" && body !== null && "error" in body) {
    const value = (body as { error: unknown }).error;
    if (typeof value === "string" && value !== "") return value;
  }
  return fallback;
}
