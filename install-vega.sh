#!/usr/bin/env bash
# install-vega.sh — build and install the vega CLI
#
# This script builds the claw binary (release profile) and installs a
# `vega` wrapper to ~/.local/bin so you can run `vega` from anywhere.
#
# Usage:
#   bash install-vega.sh           # install to ~/.local/bin/vega
#   bash install-vega.sh --prefix /usr/local   # custom prefix (installs to /usr/local/bin/vega)
#   bash install-vega.sh --debug   # debug build (faster compile, larger binary)
#   bash install-vega.sh --help

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    RESET="$(tput sgr0)"; BOLD="$(tput bold)"; DIM="$(tput dim)"
    RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"; CYAN="$(tput setaf 6)"
else
    RESET=""; BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

STEP=0; TOTAL=5
step() { STEP=$((STEP+1)); printf '\n%s[%d/%d]%s %s%s%s\n' "${BLUE}" "${STEP}" "${TOTAL}" "${RESET}" "${BOLD}" "$1" "${RESET}"; }
info() { printf '%s  ->%s %s\n' "${CYAN}" "${RESET}" "$1"; }
ok()   { printf '%s  ok%s %s\n' "${GREEN}" "${RESET}" "$1"; }
warn() { printf '%s warn%s %s\n' "${YELLOW}" "${RESET}" "$1"; }
die()  { printf '%s  error%s %s\n' "${RED}" "${RESET}" "$1" >&2; exit 1; }

print_banner() {
    printf '%s' "${BOLD}"
    cat <<'EOF'
  __   ___  ____  __
  \ \ / / |/ /  \/  |
   \ V /| ' /| |\/| |
    \_/ |_|\_\_|  |_|

EOF
    printf '%s  Vega CLI installer%s\n\n' "${DIM}" "${RESET}"
}

print_usage() {
    cat <<'EOF'
Usage: bash install-vega.sh [options]

Options:
  --prefix PATH   Install to PATH/bin/vega  (default: ~/.local)
  --debug         Build debug profile (faster, larger binary)
  --no-build      Skip the cargo build step (use existing binary)
  --help          Show this help

After install, add this to your shell profile if needed:
  export PATH="$HOME/.local/bin:$PATH"
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────

PREFIX="${HOME}/.local"
PROFILE="release"
NO_BUILD=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)    PREFIX="$2"; shift ;;
        --prefix=*)  PREFIX="${1#*=}" ;;
        --debug)     PROFILE="debug" ;;
        --no-build)  NO_BUILD=1 ;;
        -h|--help)   print_usage; exit 0 ;;
        *)           die "unknown argument: $1" ;;
    esac
    shift
done

INSTALL_DIR="${PREFIX}/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="${SCRIPT_DIR}/rust"

print_banner

# ── Step 1: check prerequisites ───────────────────────────────────────────────

step "Checking prerequisites"

# curl is required (vega uses it to health-check the bonsai server)
command -v curl >/dev/null 2>&1 \
    && ok "curl found" \
    || die "curl not found. Install it: brew install curl  (or: sudo apt-get install curl)"

if [ "${NO_BUILD}" -eq 0 ]; then
    # Auto-source rustup env if rustc not on PATH yet
    if ! command -v rustc >/dev/null 2>&1; then
        if [ -f "${HOME}/.cargo/env" ]; then
            # shellcheck source=/dev/null
            source "${HOME}/.cargo/env"
        fi
    fi
    if ! command -v rustc >/dev/null 2>&1; then
        cat >&2 <<'RUST_HELP'
  error rustc not found in PATH.

  Install Rust with:
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source "$HOME/.cargo/env"

  Then re-run this installer.
RUST_HELP
        exit 1
    fi
    ok "rustc $(rustc --version 2>/dev/null | cut -d' ' -f2)"
    ok "cargo $(cargo --version 2>/dev/null | cut -d' ' -f2)"
fi

# Warn if bonsai_core_001 does not look set up
BONSAI_DIR="${HOME}/code/bonsai_core_001"
if [ ! -d "${BONSAI_DIR}" ]; then
    warn "bonsai_core_001 not found at ${BONSAI_DIR}"
    warn "clone it: git clone https://github.com/carlosvega20/bonsai_core_001 ${BONSAI_DIR}"
elif [ ! -d "${BONSAI_DIR}/.venv" ]; then
    warn "bonsai_core_001 venv not set up — run:"
    warn "  cd ${BONSAI_DIR} && python3.12 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
else
    ok "bonsai_core_001 found at ${BONSAI_DIR}"
fi

# ── Step 2: build ─────────────────────────────────────────────────────────────

step "Building claw binary (${PROFILE} profile)"

if [ "${NO_BUILD}" -eq 1 ]; then
    warn "skipping build (--no-build)"
else
    [ -d "${RUST_DIR}" ] || die "rust/ directory not found at ${RUST_DIR}"
    [ -f "${RUST_DIR}/Cargo.toml" ] || die "Cargo.toml not found at ${RUST_DIR}/Cargo.toml"

    info "running cargo build${PROFILE:+ --${PROFILE}} --workspace"
    info "this may take a few minutes on the first build"

    CARGO_FLAGS=("build" "--workspace")
    [ "${PROFILE}" = "release" ] && CARGO_FLAGS+=("--release")

    (cd "${RUST_DIR}" && CARGO_TERM_COLOR="${CARGO_TERM_COLOR:-always}" cargo "${CARGO_FLAGS[@]}")
fi

CLAW_BIN="${RUST_DIR}/target/${PROFILE}/claw"
[ -x "${CLAW_BIN}" ] || die "binary not found at ${CLAW_BIN} — build may have failed"
ok "binary ready: ${CLAW_BIN}"

# ── Step 3: install the claw binary ───────────────────────────────────────────

step "Installing binary"

mkdir -p "${INSTALL_DIR}"

INSTALLED_CLAW="${INSTALL_DIR}/claw-vega"
cp "${CLAW_BIN}" "${INSTALLED_CLAW}"
chmod +x "${INSTALLED_CLAW}"
ok "claw binary installed to ${INSTALLED_CLAW}"

# ── Step 4: install the vega wrapper ─────────────────────────────────────────

step "Installing vega wrapper"

VEGA_SCRIPT="${INSTALL_DIR}/vega"

cat > "${VEGA_SCRIPT}" <<VEGA_EOF
#!/usr/bin/env bash
# vega — local AI coding assistant (backed by bonsai_core_001)
# Installed by install-vega.sh on $(date +%Y-%m-%d)

BONSAI_URL="\${BONSAI_URL:-http://localhost:9001}"

if ! curl -sf "\${BONSAI_URL}/health" >/dev/null 2>&1; then
    cat >&2 <<MSG
vega: bonsai_core_001 is not running at \${BONSAI_URL}

Start it first:
  cd ~/code/bonsai_core_001 && bash start.sh

MSG
    exit 1
fi

[ -n "\${BONSAI_MODEL:-}" ] && export BONSAI_DEFAULT_MODEL="\${BONSAI_MODEL}"

export ANTHROPIC_BASE_URL="\${BONSAI_URL}"
export ANTHROPIC_API_KEY="bonsai-local"

exec "${INSTALLED_CLAW}" "\$@"
VEGA_EOF

chmod +x "${VEGA_SCRIPT}"
ok "vega installed to ${VEGA_SCRIPT}"

# ── Step 5: PATH check and next steps ─────────────────────────────────────────

step "Verifying installation"

PATH_ADDED=0
if command -v vega >/dev/null 2>&1; then
    ok "vega is already on your PATH"
else
    warn "vega is not yet on your PATH"
    # Auto-append to shell profile if user consents (non-interactive: just print)
    SHELL_PROFILE=""
    if [ -f "${HOME}/.zshrc" ]; then SHELL_PROFILE="${HOME}/.zshrc"
    elif [ -f "${HOME}/.bashrc" ]; then SHELL_PROFILE="${HOME}/.bashrc"
    elif [ -f "${HOME}/.bash_profile" ]; then SHELL_PROFILE="${HOME}/.bash_profile"
    fi

    if [ -n "${SHELL_PROFILE}" ]; then
        if ! grep -q "${INSTALL_DIR}" "${SHELL_PROFILE}" 2>/dev/null; then
            {
                echo ""
                echo "# Added by install-vega.sh ($(date +%Y-%m-%d)) — vega CLI"
                echo "export PATH=\"${INSTALL_DIR}:\$PATH\""
                echo "[ -f \"\$HOME/.cargo/env\" ] && source \"\$HOME/.cargo/env\""
            } >> "${SHELL_PROFILE}"
            ok "PATH added to ${SHELL_PROFILE}"
            PATH_ADDED=1
        else
            ok "${INSTALL_DIR} already in ${SHELL_PROFILE}"
        fi
    else
        warn "add this to your shell profile:"
        printf '\n    %sexport PATH="%s:\$PATH"%s\n' "${BOLD}" "${INSTALL_DIR}" "${RESET}"
        printf '    %s[ -f "\$HOME/.cargo/env" ] && source "\$HOME/.cargo/env"%s\n\n' "${BOLD}" "${RESET}"
    fi
fi

cat <<EOF

${GREEN}${BOLD}Vega is installed!${RESET}

  Binary : ${BOLD}${INSTALLED_CLAW}${RESET}
  Wrapper: ${BOLD}${VEGA_SCRIPT}${RESET}

${BOLD}Getting started:${RESET}

  ${DIM}# 1. Start the bonsai inference server (in a separate terminal)${RESET}
  cd ~/code/bonsai_core_001 && bash start.sh

  ${DIM}# 2. Run vega${RESET}
  vega                                    ${DIM}# interactive REPL${RESET}
  vega "explain this codebase"            ${DIM}# one-shot prompt${RESET}
  vega --dangerously-skip-permissions "refactor main.py"

  ${DIM}# 3. Override the inference model${RESET}
  BONSAI_MODEL=ollama:llama3.2 vega "task"

  ${DIM}# 4. Run a health check inside the REPL${RESET}
  vega → /doctor

For full documentation see: ${BOLD}VEGA.md${RESET}
EOF

if [ "${PATH_ADDED}" -eq 1 ]; then
    printf '\n%s  →%s Reload your shell: %ssource %s%s\n\n' \
        "${CYAN}" "${RESET}" "${BOLD}" "${SHELL_PROFILE}" "${RESET}"
fi
