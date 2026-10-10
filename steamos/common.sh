# shellcheck shell=bash
# -----------------------------------------------------------------------------
# g13 SteamOS support: shared helpers (sourced, not executed)
# -----------------------------------------------------------------------------

# Upstream used when this steamos/ directory is distributed on its own.
G13_UPSTREAM_URL="${G13_UPSTREAM_URL:-https://github.com/khampf/g13.git}"

# Install locations (all under $HOME so they survive SteamOS updates).
G13_BIN_DIR="${HOME}/.local/bin"
G13_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/g13"
G13_UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
G13_UNIT_NAME="g13d.service"
G13_UDEV_RULE="/etc/udev/rules.d/91-g13.rules"

# Homebrew formulae required to build g13d and g13d's runtime libraries.
G13_BREW_DEPS=(gcc cmake make pkgconf glibc linux-headers libusb libevdev log4cpp)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Locate Homebrew and load its environment. Sets BREW_PREFIX.
load_brew_env() {
    local candidate
    if command -v brew >/dev/null 2>&1; then
        BREW_PREFIX="$(brew --prefix)"
    else
        for candidate in /home/linuxbrew/.linuxbrew "${HOME}/.linuxbrew"; do
            if [[ -x "${candidate}/bin/brew" ]]; then
                BREW_PREFIX="${candidate}"
                break
            fi
        done
    fi
    [[ -n "${BREW_PREFIX:-}" ]] || die "Homebrew not found. Install it first: https://brew.sh"
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
    export BREW_PREFIX
}

# Install any missing Homebrew formulae.
ensure_brew_deps() {
    local f missing=()
    for f in "${G13_BREW_DEPS[@]}"; do
        brew list --versions "${f}" >/dev/null 2>&1 || missing+=("${f}")
    done
    if (( ${#missing[@]} )); then
        log "Installing Homebrew dependencies: ${missing[*]}"
        brew install "${missing[@]}"
    else
        log "Homebrew dependencies already installed"
    fi
}

# Print the g13 source directory. Uses the repo this steamos/ dir lives in;
# otherwise clones upstream into ~/.local/src/g13.
resolve_source_dir() {
    local parent
    parent="$(cd "${STEAMOS_DIR}/.." && pwd)"
    if [[ -f "${parent}/CMakeLists.txt" && -f "${parent}/g13_main.cpp" ]]; then
        printf '%s\n' "${parent}"
        return
    fi
    local dest="${HOME}/.local/src/g13"
    if [[ ! -f "${dest}/CMakeLists.txt" ]]; then
        command -v git >/dev/null 2>&1 || die "git is required to fetch the g13 sources"
        log "Cloning ${G13_UPSTREAM_URL} into ${dest}" >&2
        git clone --depth 1 "${G13_UPSTREAM_URL}" "${dest}" >&2
    fi
    printf '%s\n' "${dest}"
}
