#!/usr/bin/env bash
# Tryaksh CLI dev/source setup for Linux & macOS. Mirrors setup.ps1.
#
# Usage:
#   ./setup.sh                 # full setup: prereqs, pinned bun, bun install, npm link
#   ./setup.sh --skip-bun      # do not auto-install Bun (use existing on PATH)
#   ./setup.sh --skip-link     # skip `npm link` (run from source via `bun run tryaksh`)
#   ./setup.sh --show-welcome  # show the welcome banner again
#   ./setup.sh --no-clean      # skip cleaning node_modules even if verify fails

set -euo pipefail

SKIP_BUN_INSTALL=false
SKIP_LINK=false
SHOW_WELCOME_AGAIN=false
NO_CLEAN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-bun|--skip-bun-install) SKIP_BUN_INSTALL=true; shift ;;
    --skip-link)                   SKIP_LINK=true; shift ;;
    --show-welcome|--show-welcome-again) SHOW_WELCOME_AGAIN=true; shift ;;
    --no-clean)                    NO_CLEAN=true; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
DCYAN='\033[1;36m'
NC='\033[0m'

step()  { printf "\n${CYAN}==> %s${NC}\n" "$1"; }
ok()    { printf "${GREEN}OK  %s${NC}\n" "$1"; }
warn()  { printf "${YELLOW}WARN  %s${NC}\n" "$1"; }
fail()  { printf "${RED}ERROR  %s${NC}\n" "$1" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

sudo_cmd() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    fail "Need root or sudo for: $*"
  fi
}

add_common_path_entries() {
  local entries=(
    "$HOME/.bun/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.local/bin"
    "/usr/local/bin"
  )
  local entry
  for entry in "${entries[@]}"; do
    if [[ -d "$entry" && ":$PATH:" != *":$entry:"* ]]; then
      PATH="$entry:$PATH"
    fi
  done
  export PATH
}

detect_pkg_manager() {
  if have apt-get; then echo apt
  elif have dnf;    then echo dnf
  elif have pacman; then echo pacman
  elif have zypper; then echo zypper
  elif have brew;   then echo brew
  else echo ""
  fi
}

# Read the pinned Bun version from package.json packageManager field.
read_pinned_bun_version() {
  # Looks for: "packageManager": "bun@X.Y.Z"
  local raw
  raw=$(grep -E '"packageManager"' package.json 2>/dev/null | head -1)
  echo "$raw" | sed -E 's/.*"bun@([0-9]+\.[0-9]+\.[0-9]+)".*/\1/' | head -1
}

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# macOS only: ensure Xcode Command Line Tools are installed and the active
# developer path actually points at a usable toolchain. tree-sitter-* and
# other native postinstalls fail with "xcrun: invalid active developer path"
# when CLT is missing or stale.
ensure_xcode_clt() {
  is_macos || return 0

  local active_path=""
  active_path=$(xcode-select -p 2>/dev/null || true)

  if [[ -n "$active_path" && -x "$active_path/usr/bin/xcrun" ]] && have clang && have make; then
    ok "Xcode Command Line Tools are installed ($active_path)"
    return
  fi

  warn "Xcode Command Line Tools are missing or broken (path: '${active_path:-unset}')"
  step "Triggering Xcode Command Line Tools installer"

  if ! xcode-select --install 2>&1 | grep -qiE "install requested|already installed"; then
    warn "Could not invoke xcode-select --install automatically."
  fi

  cat <<EOF

A graphical dialog should appear titled "The command-line developer tools require an installation". Click "Install" and wait for it to finish (typically 5-15 minutes).

When the installer completes, re-run:
  ./setup.sh

If the dialog did not appear:
  sudo rm -rf /Library/Developer/CommandLineTools
  xcode-select --install

EOF
  fail "Re-run ./setup.sh after Xcode Command Line Tools finish installing."
}

# Compare the running Node major version against MIN_NODE_MAJOR. Older Node
# (especially EOL releases like 19.x) fails native-builds via node-gyp@12.
MIN_NODE_MAJOR=20
require_node_version() {
  have node || return 0
  local ver major
  ver=$(node --version 2>/dev/null | sed 's/^v//')
  major=$(echo "$ver" | cut -d. -f1)
  if [[ -z "$major" || ! "$major" =~ ^[0-9]+$ ]]; then
    warn "Could not parse Node version '$ver' — continuing."
    return 0
  fi
  if (( major >= MIN_NODE_MAJOR )); then
    return 0
  fi

  warn "Node $ver is older than the minimum required ($MIN_NODE_MAJOR.x LTS)."
  if is_macos && have brew; then
    cat <<EOF

To upgrade Node on macOS via Homebrew:
  brew install node@22
  brew link --force --overwrite node@22
  node --version

Then re-run: ./setup.sh
EOF
  elif have apt-get; then
    cat <<EOF

To upgrade Node on Ubuntu/Debian via NodeSource:
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
  node --version

Then re-run: ./setup.sh
EOF
  else
    cat <<EOF

Install Node $MIN_NODE_MAJOR LTS or higher (https://nodejs.org) and re-run ./setup.sh.
EOF
  fi
  fail "Node $ver is below the required minimum ($MIN_NODE_MAJOR.x)."
}

ensure_system_prereqs() {
  local pm; pm=$(detect_pkg_manager)
  local need=()

  have curl  || need+=(curl)
  have unzip || need+=(unzip)
  have git   || need+=(git)
  # Build tools so optional node-pty / native deps can compile if needed.
  have make  || need+=(make)
  have gcc   || need+=(gcc)
  have python3 || need+=(python3)

  if [[ ${#need[@]} -eq 0 ]]; then
    ok "System prerequisites are present"
    return
  fi

  step "Installing system prerequisites: ${need[*]}"
  case "$pm" in
    apt)
      sudo_cmd apt-get update -y
      # build-essential pulls in make+gcc; install both groups regardless.
      sudo_cmd apt-get install -y curl unzip git build-essential python3
      ;;
    dnf)
      sudo_cmd dnf install -y curl unzip git make gcc gcc-c++ python3
      ;;
    pacman)
      sudo_cmd pacman -Sy --noconfirm curl unzip git base-devel python
      ;;
    zypper)
      sudo_cmd zypper install -y curl unzip git make gcc gcc-c++ python3
      ;;
    brew)
      brew install curl unzip git python@3.12 || brew install curl unzip git python3
      ;;
    *)
      fail "No supported package manager. Install these manually and re-run: ${need[*]}"
      ;;
  esac
  ok "System prerequisites installed"
}

ensure_node_and_npm() {
  add_common_path_entries

  if have node && have npm; then
    ok "Node and npm are available ($(node --version), npm $(npm --version))"
    return
  fi

  warn "Node/npm were not found on PATH"
  local pm; pm=$(detect_pkg_manager)
  case "$pm" in
    apt)
      step "Installing Node.js LTS via NodeSource (apt)"
      if ! curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo_cmd -E bash -; then
        warn "NodeSource setup failed — falling back to apt's nodejs package."
      fi
      sudo_cmd apt-get install -y nodejs
      ;;
    dnf)    sudo_cmd dnf install -y nodejs npm ;;
    pacman) sudo_cmd pacman -Sy --noconfirm nodejs npm ;;
    zypper) sudo_cmd zypper install -y nodejs npm ;;
    brew)
      brew install node@22
      brew link --force --overwrite node@22 || true
      ;;
    *)      fail "No supported package manager found. Install Node.js LTS manually (https://nodejs.org), then re-run ./setup.sh." ;;
  esac

  add_common_path_entries
  have node && have npm || fail "Node.js LTS and npm are still not on PATH. Open a new shell and re-run ./setup.sh."
  ok "Node and npm are available ($(node --version), npm $(npm --version))"
}

# Install Bun pinned to the version in package.json#packageManager.
# If the running Bun is a different patch version we re-install the pinned one,
# because the lockfile is built against that exact Bun and Bun's isolated linker
# is sensitive to minor version drift.
ensure_bun() {
  add_common_path_entries

  local pinned; pinned=$(read_pinned_bun_version)
  if [[ -z "$pinned" ]]; then
    warn "Could not read packageManager from package.json — accepting any Bun version."
  fi

  local current=""
  if have bun; then current=$(bun --version 2>/dev/null | tr -d '[:space:]' || true); fi

  if [[ -n "$current" && ( -z "$pinned" || "$current" == "$pinned" ) ]]; then
    ok "Bun is available ($current)"
    return
  fi

  if [[ "$SKIP_BUN_INSTALL" == "true" ]]; then
    if [[ -z "$current" ]]; then
      fail "Bun was not found and --skip-bun was passed."
    fi
    warn "Bun $current does not match pinned $pinned but --skip-bun was passed; continuing."
    return
  fi

  if [[ -n "$current" ]]; then
    warn "Bun $current is installed but package.json pins $pinned — installing $pinned."
  fi

  step "Installing Bun $pinned"
  if [[ -n "$pinned" ]]; then
    if ! curl -fsSL "https://bun.sh/install" | bash -s "bun-v$pinned"; then
      warn "Pinned Bun install failed — falling back to latest."
      curl -fsSL https://bun.sh/install | bash
    fi
  else
    curl -fsSL https://bun.sh/install | bash
  fi
  add_common_path_entries

  if ! have bun; then
    fail "Bun installed but is not on PATH yet. Open a new shell (or 'source ~/.bashrc') and re-run ./setup.sh."
  fi
  ok "Bun is available ($(bun --version))"
}

# Make sure `npm link` can write to npm's prefix without sudo.
# If the prefix is owned by root we redirect npm to ~/.npm-global, which is the
# convention recommended by npm docs for non-root users.
ensure_npm_user_prefix() {
  local prefix; prefix=$(npm config get prefix 2>/dev/null || echo "")
  if [[ -z "$prefix" ]]; then
    return
  fi
  if [[ -w "$prefix" ]]; then
    return
  fi
  if [[ -w "$prefix/bin" ]]; then
    return
  fi

  local user_prefix="$HOME/.npm-global"
  step "npm prefix '$prefix' is not user-writable — switching npm to $user_prefix"
  mkdir -p "$user_prefix/bin"
  npm config set prefix "$user_prefix"
  add_common_path_entries

  local profile=""
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
    fish) profile="$HOME/.config/fish/config.fish" ;;
    *)    profile="$HOME/.profile" ;;
  esac
  if [[ -n "$profile" && -f "$profile" ]] && ! grep -q ".npm-global/bin" "$profile" 2>/dev/null; then
    if [[ "$profile" == *config.fish ]]; then
      printf '\n# tryaksh: npm user prefix\nfish_add_path %s/bin\n' "$user_prefix" >> "$profile"
    else
      printf '\n# tryaksh: npm user prefix\nexport PATH="%s/bin:$PATH"\n' "$user_prefix" >> "$profile"
    fi
    ok "Appended $user_prefix/bin to PATH in $profile (restart shell to make it persistent)"
  fi
}

assert_repo_root() {
  if [[ ! -f "./package.json" || ! -d "./packages/opencode" ]]; then
    fail "Run this script from the tryaksh-cli repository root."
  fi
}

# Verify that bun's install left the dep graph in a state where the CLI can
# actually start. Returns 0 if healthy, non-zero if a clean reinstall is needed.
verify_install() {
  # Quick structural check: @babel/types' sub-dep must be linkable.
  local babel_types_dir
  babel_types_dir=$(ls -d node_modules/.bun/@babel+types@*/node_modules/@babel/helper-validator-identifier 2>/dev/null | head -1 || true)
  if [[ -z "$babel_types_dir" || ! -d "$babel_types_dir" ]]; then
    # Hoisted layouts won't have .bun/ — accept node_modules/@babel/helper-validator-identifier too.
    if [[ ! -d "node_modules/@babel/helper-validator-identifier" ]]; then
      warn "Sub-dep @babel/helper-validator-identifier is missing in node_modules"
      return 1
    fi
  fi

  # Functional check: bun must be able to start the CLI source.
  local out
  if ! out=$(timeout 45 bun run --cwd packages/opencode --conditions=browser src/index.ts --help 2>&1); then
    warn "bun run tryaksh --help failed during verification"
    echo "--- last 20 lines ---" >&2
    echo "$out" | tail -20 >&2
    return 1
  fi
  return 0
}

show_first_run_welcome() {
  local state_dir="$HOME/.local/share/tryaksh"
  local marker="$state_dir/setup-welcome-shown"

  if [[ -f "$marker" && "$SHOW_WELCOME_AGAIN" != "true" ]]; then
    printf "\n${GREEN}Tryaksh CLI is ready.${NC}\n"
    printf "${GREEN}Run 'tryaksh' from any project folder to start.${NC}\n"
    return
  fi

  mkdir -p "$state_dir"
  cat <<EOF

$(printf "${DCYAN}================================================================${NC}")
$(printf "${WHITE}                         TRYAKSH CLI${NC}")
$(printf "${DCYAN}================================================================${NC}")

$(printf "${WHITE}Welcome to Tryaksh Innovations.${NC}")

$(printf "${GRAY}You made it this far because you are here to build, learn,${NC}")
$(printf "${GRAY}and help shape the revolution we are working toward.${NC}")

$(printf "${GREEN}Tryaksh CLI is now ready on this machine.${NC}")
$(printf "${GRAY}It is built for your ease, your efficiency, and the quality of${NC}")
$(printf "${GRAY}the engineering work you do every day.${NC}")

$(printf "${WHITE}You now have AI assistance inside your projects:${NC}")
$(printf "  ${CYAN}tryaksh${NC}")

$(printf "${GRAY}Open any project folder, run the command, and start building.${NC}")

$(printf "${WHITE}Welcome aboard. Let us build the future with care.${NC}")
$(printf "${DCYAN}================================================================${NC}")
EOF
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker"
}

printf "${WHITE}Tryaksh CLI setup${NC}\n"
assert_repo_root

if is_macos; then
  step "Checking Xcode Command Line Tools (macOS)"
  ensure_xcode_clt
fi

step "Checking system prerequisites"
ensure_system_prereqs

step "Checking Node and npm"
ensure_node_and_npm

step "Verifying Node version"
require_node_version

step "Checking Bun (pinned to package.json packageManager)"
ensure_bun

step "Configuring npm prefix"
ensure_npm_user_prefix

step "Installing project dependencies"
bun install

step "Verifying dependency graph and CLI entrypoint"
if ! verify_install; then
  if [[ "$NO_CLEAN" == "true" ]]; then
    fail "verify failed and --no-clean was passed."
  fi
  warn "Verify failed — wiping node_modules and reinstalling"
  rm -rf node_modules
  bun install
  if ! verify_install; then
    fail "Verify still failing after clean reinstall. Inspect the output above and rerun ./setup.sh --no-clean for diagnostics."
  fi
fi
ok "Dependency graph is healthy and tryaksh source starts correctly"

if [[ "$SKIP_LINK" != "true" ]]; then
  step "Linking the tryaksh command"
  if ! npm link --force; then
    fail "npm link failed. Try: npm config set prefix ~/.npm-global && ./setup.sh"
  fi
  add_common_path_entries
fi

step "Verifying global tryaksh command"
if have tryaksh; then
  if ! timeout 15 tryaksh --version >/dev/null 2>&1; then
    warn "tryaksh is on PATH but exited non-zero on --version. The source-mode CLI still runs via 'bun run tryaksh'."
  else
    ok "tryaksh --version succeeded ($(tryaksh --version 2>/dev/null))"
  fi
else
  if [[ "$SKIP_LINK" != "true" ]]; then
    warn "tryaksh not found on PATH. Restart your shell, or add \$(npm config get prefix)/bin to PATH."
  fi
fi

show_first_run_welcome
