# Math-Coding Install Skill for AI agents

This skill teaches opencode (and other agents) how to add
math-coding to a user's existing project.

## When to load

Load this skill when the user says one of:

- "Add math-coding to this project"
- "Set up math-coding here"
- "I want to use the math-coding convention"
- "Initialize the specs directory"
- "Install the math-coding verifier"

## What this skill does

1. Reads `.mathcodingrc` (or creates one if missing)
2. Copies `core/`, `schemas/`, `01-Theory/` from the
   math-coding source into the project's `specs/` or `math/`
   directory
3. Copies `.cursorrules` and `.opencode/` if the user uses
   Cursor or opencode
4. Runs the verifier in dry-run to confirm it works
5. Reports what was installed and where

## Steps for the agent

### 1. Locate the math-coding source

Ask the user where the math-coding repository lives on
their system, or check standard locations:

- `~/Desktop/math-coding/`
- `./math-coding/` (sibling directory)
- `/path/to/math-coding` (user-provided)

If unknown, **ask the user** before proceeding. Do not
guess.

### 2. Read or create `.mathcodingrc`

Check for `.mathcodingrc` at the project root. If it
exists, read `packets_dir` (default: `specs`).

If it does not exist, ask the user:

> I see no `.mathcodingrc` in this project. Where should
> packets live? Default is `specs/`. Alternative: `math/`.

Or, with judgment (if the user has been clear), create
`.mathcodingrc` with default values.

### 3. Copy the convention

```sh
SOURCE="/path/to/math-coding"
TARGET="$PROJECT_ROOT/$PACKETS_DIR"
mkdir -p "$TARGET"
cp -r "$SOURCE/core" "$TARGET/"
cp -r "$SOURCE/schemas" "$TARGET/"
cp "$SOURCE/examples/self-application/verify-consistency.sh" "$TARGET/"
chmod +x "$TARGET/verify-consistency.sh"
```

If the user has Cursor, also:

```sh
cp "$SOURCE/.cursorrules" "$PROJECT_ROOT/"
```

If the user has opencode, also:

```sh
cp -r "$SOURCE/.opencode" "$PROJECT_ROOT/"
```

### 4. Verify the install

Run:

```sh
sh "$TARGET/verify-consistency.sh"
```

If it fails, the install is broken. Investigate before
proceeding.

If it succeeds, the convention is in place. Report:

> Installed math-coding into `<packets_dir>/`. The
> convention is at `<packets_dir>/core/`. The verifier is
> at `<packets_dir>/verify-consistency.sh`. You can now
> create packets with `sh .opencode/commands/mathpacket <id>`.

### 5. Suggest first packet

If the project is fresh, suggest creating a packet:

> Would you like to open your first packet? Run
> `sh .opencode/commands/mathpacket <feature-name>` to
> create one.

If the project already has features, ask which feature
to capture first.

## What NOT to do

- Do not move the user's source code into the packets
  directory. Code stays in `src/`, `tests/`, etc.
- Do not run `verify-consistency.sh` against the user's
  code. The verifier checks packet structure, not user code.
- Do not modify the user's existing files. Adding
  `.cursorrules` is fine; modifying `package.json` is not.
- Do not create a packet without the user's request. The
  agent should ask before opening packets.

## Uninstall

To remove math-coding from a project:

```sh
rm -rf "$PROJECT_ROOT/specs/"      # or math/
rm "$PROJECT_ROOT/.cursorrules"    # if it was added
rm -rf "$PROJECT_ROOT/.opencode"   # if it was added
rm "$PROJECT_ROOT/.mathcodingrc"   # if it was created
```

The agent should not run this without explicit user
confirmation.