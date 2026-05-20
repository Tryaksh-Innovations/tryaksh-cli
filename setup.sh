#!/usr/bin/env bash
# Tryaksh CLI dev/source setup for Linux & macOS.
# Mirrors setup.ps1.
#
# Usage:
#   ./setup.sh                 # install Bun if missing, bun install, npm link
#   ./setup.sh --skip-bun      # do not auto-install Bun
#   ./setup.sh --skip-link     # skip `npm link` (run from source via `bun run tryaksh`)
#   ./setup.sh --show-welcome  # show the welcome banner again

set -euo pipefail

SKIP_BUN_INSTALL=false
SKIP_LINK=false
SHOW_WELCOME_AGAIN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-bun|--skip-bun-install) SKIP_BUN_INSTALL=true; shift ;;
    --skip-link)                   SKIP_LINK=true; shift ;;
    --show-welcome|--show-welcome-again) SHOW_WELCOME_AGAIN=true; shift ;;
    -h|--help)
      sed -n '2,11p' "$0"
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

add_common_path_entries() {
  local entries=(
    "$HOME/.bun/bin"
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
      if [[ $EUID -ne 0 ]] && ! have sudo; then
        fail "Need root or sudo to install Node.js. Install Node.js LTS manually, then re-run ./setup.sh."
      fi
      local SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
      if ! curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -; then
        warn "NodeSource setup failed — falling back to apt's nodejs package."
      fi
      $SUDO apt-get install -y nodejs
      ;;
    dnf)
      [[ $EUID -ne 0 ]] && local SUDO="sudo" || local SUDO=""
      $SUDO dnf install -y nodejs npm
      ;;
    pacman)
      [[ $EUID -ne 0 ]] && local SUDO="sudo" || local SUDO=""
      $SUDO pacman -Sy --noconfirm nodejs npm
      ;;
    zypper)
      [[ $EUID -ne 0 ]] && local SUDO="sudo" || local SUDO=""
      $SUDO zypper install -y nodejs npm
      ;;
    brew)
      brew install node
      ;;
    *)
      fail "No supported package manager found. Install Node.js LTS manually (https://nodejs.org), then re-run ./setup.sh."
      ;;
  esac

  add_common_path_entries
  have node && have npm || fail "Node.js LTS and npm are still not on PATH. Open a new shell and re-run ./setup.sh."
  ok "Node and npm are available ($(node --version), npm $(npm --version))"
}

ensure_bun() {
  add_common_path_entries

  if have bun; then
    ok "Bun is available ($(bun --version))"
    return
  fi

  if [[ "$SKIP_BUN_INSTALL" == "true" ]]; then
    fail "Bun was not found and --skip-bun was passed."
  fi

  step "Installing Bun"
  curl -fsSL https://bun.sh/install | bash
  add_common_path_entries

  if ! have bun; then
    fail "Bun installed but is not on PATH yet. Open a new shell (or 'source ~/.bashrc') and re-run ./setup.sh."
  fi

  ok "Bun is available ($(bun --version))"
}

assert_repo_root() {
  if [[ ! -f "./package.json" || ! -d "./packages/opencode" ]]; then
    fail "Run this script from the tryaksh-cli repository root."
  fi
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

step "Checking required tools"
ensure_node_and_npm
ensure_bun

step "Installing project dependencies"
bun install

if [[ "$SKIP_LINK" != "true" ]]; then
  step "Linking the tryaksh command"
  # `npm link --force` works without sudo when npm's prefix is user-owned (default with nvm/Volta/bun-installed Node).
  # On a system-wide Node, `sudo npm link` may be required — let npm fail naturally and the user can re-run with sudo.
  npm link --force
fi

step "Verifying Tryaksh CLI"
if ! tryaksh --version; then
  fail "tryaksh verification failed. If npm link wrote to a global prefix not on your PATH, run 'npm config get prefix' and add '\$(npm config get prefix)/bin' to PATH."
fi

show_first_run_welcome
