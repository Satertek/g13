#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# g13 SteamOS support: uninstall
# Usage: steamos/uninstall.sh [--purge]   (--purge also deletes ~/.config/g13)
# Homebrew packages are left installed.
# -----------------------------------------------------------------------------
set -euo pipefail

STEAMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steamos/common.sh
source "${STEAMOS_DIR}/common.sh"

PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

log "Stopping and disabling ${G13_UNIT_NAME}"
systemctl --user disable --now "${G13_UNIT_NAME}" 2>/dev/null || true
rm -f "${G13_UNIT_DIR}/${G13_UNIT_NAME}"
systemctl --user daemon-reload || true

log "Removing binaries"
rm -f "${G13_BIN_DIR}/g13d" "${G13_BIN_DIR}/pbm2lpbm" "${G13_BIN_DIR}/g13-profile"

if [[ -e "${G13_UDEV_RULE}" ]]; then
    log "Removing ${G13_UDEV_RULE} (sudo required)"
    sudo rm -f "${G13_UDEV_RULE}"
    sudo udevadm control --reload-rules
fi

if (( PURGE )); then
    log "Removing ${G13_CONFIG_DIR}"
    rm -rf "${G13_CONFIG_DIR}"
else
    log "Keeping configuration in ${G13_CONFIG_DIR} (use --purge to remove)"
fi
