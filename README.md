# Tryaksh CLI

AI-powered development tool by Tryaksh Innovations.

Tryaksh CLI is a team-ready command-line coding assistant. The current agenda is to provide the team with a local, source-runnable CLI named `tryaksh`, keep the proven provider/auth behavior from the upstream engine, and separate Tryaksh install/data paths from any other coding assistant setup.

## Quick Start For Team Members

From source on Windows (PowerShell):

```powershell
git clone https://github.com/tryaksh-innovations/tryaksh-cli.git
cd tryaksh-cli
.\setup.ps1
tryaksh
```

If PowerShell blocks local scripts, run this once from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

From source on Ubuntu / Linux / macOS (bash or zsh):

```bash
git clone https://github.com/tryaksh-innovations/tryaksh-cli.git
cd tryaksh-cli
./setup.sh
tryaksh
```

Both setup scripts check Node/npm + the system prereqs (`curl`, `unzip`, `git`, `make`, `gcc`, `python3`), install Bun pinned to the exact version in `package.json#packageManager`, run `bun install`, verify the dependency graph by running `bun run tryaksh --help`, and link the global `tryaksh` command. If anything fails verification, the script wipes `node_modules` and reinstalls once before giving up.

On Ubuntu the script uses `apt` (via NodeSource) when Node.js is absent; on Fedora it uses `dnf`, on Arch `pacman`, on openSUSE `zypper`, on macOS `brew`. **The Linux script may prompt once for your sudo password** to install `unzip` and Node.js if they are missing. If npm's global prefix is root-owned (system Node), the script automatically reconfigures npm to use `~/.npm-global` so `npm link` does not need sudo, and appends the new path to your shell rc file.

After setup, run `tryaksh` from any project:

```bash
cd path/to/project
tryaksh
```

For development without linking:

```bash
bun install
bun run tryaksh --help
```

The root package exposes the `tryaksh` command, so team members do not need to enter internal package folders. The linked command falls back to the source entrypoint when no compiled release binary is installed, so it is usable during development.

After pulling updates, fully restart `tryaksh` and start a fresh session with `/new` so the latest identity and branding prompts are loaded.

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

The installer uses `TRYAKSH_INSTALL_DIR` first, then the legacy install-dir variable for backward compatibility, then `$HOME/.tryaksh/bin`.

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
- `TRYAKSH_*` environment variables are preferred for new Tryaksh-specific settings where added; selected legacy variables remain supported for compatibility.
- This project keeps the upstream MIT license.
