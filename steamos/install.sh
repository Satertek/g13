#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# g13 SteamOS support: build + install
#
# Installs everything under $HOME (survives SteamOS updates) except the udev
# rule, which goes to /etc/udev/rules.d (also preserved across updates).
#
#   ~/.local/bin/g13d, pbm2lpbm, g13-profile
#   ~/.config/g13/*.bind                      (existing files are kept)
#   ~/.config/g13/games/*.bind                (sample game profiles)
#   ~/.config/systemd/user/g13d.service       (enabled + started)
#   /etc/udev/rules.d/91-g13.rules            (needs sudo, only if changed)
#
# Usage: steamos/install.sh [--reset-config] [--clean]
#   --reset-config   overwrite ~/.config/g13 mode files with the shipped defaults
#   --clean          rebuild from scratch
# -----------------------------------------------------------------------------
set -euo pipefail

STEAMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steamos/common.sh
source "${STEAMOS_DIR}/common.sh"

RESET_CONFIG=0
BUILD_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --reset-config) RESET_CONFIG=1 ;;
        --clean)        BUILD_ARGS+=(--clean) ;;
        -h|--help)      sed -n '2,18p' "$0"; exit 0 ;;
        *)              die "unknown option: ${arg}" ;;
    esac
done

[[ "$(id -u)" -ne 0 ]] || die "Run as your normal user (e.g. deck), not root. sudo is requested only when needed."

# 1. Build ---------------------------------------------------------------------
"${STEAMOS_DIR}/build.sh" "${BUILD_ARGS[@]}"
load_brew_env
SRC_DIR="$(resolve_source_dir)"
BUILD_DIR="${SRC_DIR}/build"

# 2. Binaries ------------------------------------------------------------------
log "Installing binaries to ${G13_BIN_DIR}"
mkdir -p "${G13_BIN_DIR}"
# Stop first so the running binary can be replaced.
systemctl --user stop "${G13_UNIT_NAME}" 2>/dev/null || true
install -m 0755 "${BUILD_DIR}/g13d" "${BUILD_DIR}/pbm2lpbm" "${G13_BIN_DIR}/"
install -m 0755 "${STEAMOS_DIR}/g13-profile" "${G13_BIN_DIR}/"

# 3. Configuration -------------------------------------------------------------
log "Installing configuration to ${G13_CONFIG_DIR}"
mkdir -p "${G13_CONFIG_DIR}/games"
for f in "${STEAMOS_DIR}"/config/*.bind; do
    dest="${G13_CONFIG_DIR}/$(basename "${f}")"
    if [[ -e "${dest}" && ${RESET_CONFIG} -eq 0 ]]; then
        cmp -s "${f}" "${dest}" || warn "keeping customized $(basename "${f}") (use --reset-config to overwrite)"
    else
        install -m 0644 "${f}" "${dest}"
    fi
done
# Sample game profiles from the upstream repository.
if [[ -d "${SRC_DIR}/bindfiles" ]]; then
    for f in "${SRC_DIR}"/bindfiles/*.bind; do
        dest="${G13_CONFIG_DIR}/games/$(basename "${f}")"
        [[ -e "${dest}" ]] || install -m 0644 "${f}" "${dest}"
    done
fi

# 4. udev rule (root) ----------------------------------------------------------
if cmp -s "${STEAMOS_DIR}/91-g13.rules" "${G13_UDEV_RULE}" 2>/dev/null; then
    log "udev rule already up to date"
else
    log "Installing udev rule to ${G13_UDEV_RULE} (sudo required)"
    if ! sudo -v; then
        die "sudo failed. On SteamOS the 'deck' user has no password by default;
       set one with 'passwd' in Konsole, then re-run this script."
    fi
    sudo install -D -m 0644 "${STEAMOS_DIR}/91-g13.rules" "${G13_UDEV_RULE}"
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=046d
    sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput
fi

# 5. systemd user service ------------------------------------------------------
log "Installing and starting ${G13_UNIT_NAME}"
mkdir -p "${G13_UNIT_DIR}"
install -m 0644 "${STEAMOS_DIR}/g13d.service" "${G13_UNIT_DIR}/${G13_UNIT_NAME}"
systemctl --user daemon-reload
systemctl --user enable "${G13_UNIT_NAME}" >/dev/null
systemctl --user restart "${G13_UNIT_NAME}"

sleep 2
if systemctl --user is-active --quiet "${G13_UNIT_NAME}"; then
    log "g13d is running. Logs: journalctl --user -u ${G13_UNIT_NAME} -f"
else
    warn "g13d failed to start. Check: journalctl --user -u ${G13_UNIT_NAME} -e"
    exit 1
fi

cat <<EOF

Done. The G13 starts in mode M1 (WASD); M1/M2/M3 switch modes, MR returns to M1.

Per-game profiles in Steam (Properties > Launch Options):
    ~/.local/bin/g13-profile <name> %command%
where <name> matches ${G13_CONFIG_DIR}/games/<name>.bind
EOF
