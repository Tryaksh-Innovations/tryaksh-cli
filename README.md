# Tryaksh CLI

AI-powered development tool by Tryaksh Innovations.

Tryaksh CLI is a branded OpenCode-based command-line coding assistant. The current agenda is to provide the team with a local, source-runnable CLI named `tryaksh`, keep provider/auth behavior from the upstream engine, and separate Tryaksh install/data paths from a developer's existing OpenCode setup.

## Quick Start For Team Members

Prerequisites:

- Bun `1.3.13` or newer in the `1.x` line
- Git
- At least one supported AI provider configured with an API key or auth login

From source:

```bash
git clone https://github.com/tryaksh-innovations/tryaksh-cli.git
cd tryaksh-cli
bun install
bun run tryaksh --help
```

Run inside any project:

```bash
cd path/to/project
bun run /path/to/tryaksh-cli/packages/opencode/src/index.ts --help
```

For a linked local command:

```bash
cd packages/opencode
npm link
tryaksh --help
```

The linked `tryaksh` command falls back to the source entrypoint when no compiled release binary is installed, so it is usable during development.

## Install Script

Local binary install:

```bash
./install --binary ./packages/opencode/dist/tryaksh-windows-x64/bin/tryaksh.exe
```

Release install:

```bash
curl -fsSL https://raw.githubusercontent.com/tryaksh-innovations/tryaksh-cli/dev/install | bash
```

If the repository is hosted under a different owner/name, set:

```bash
TRYAKSH_GITHUB_REPO=owner/repo ./install
```

The installer uses `TRYAKSH_INSTALL_DIR` first, then `OPENCODE_INSTALL_DIR` for backward compatibility, then `$HOME/.tryaksh/bin`.

## Useful Commands

```bash
bun install
bun run tryaksh --help
bun run --cwd packages/opencode typecheck
bun run lint
bun run --cwd packages/opencode build --single --skip-embed-web-ui
```

Do not run tests from the repository root. Package tests should be run from the relevant package directory.

## Notes For Maintainers

- The public command is `tryaksh`.
- User-facing install/cache/data paths use `tryaksh` where this fork has been adapted.
- Internal workspace package names such as `@opencode-ai/core` remain from upstream to avoid a risky monorepo-wide rename.
- `TRYAKSH_*` environment variables are preferred for new Tryaksh-specific settings where added; selected `OPENCODE_*` variables remain supported for compatibility.
- This project is based on OpenCode and keeps the upstream MIT license.
