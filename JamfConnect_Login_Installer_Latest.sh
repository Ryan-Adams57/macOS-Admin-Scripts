#!/bin/zsh

# Author: https://github.com/Ryan-Adams57
# Based on original work by Sean Rabbit
# Purpose: Install Jamf Connect Login with verification and fallback support
#
# Features:
# - Downloads latest Jamf Connect DMG
# - Extracts and installs JamfConnectLogin.pkg
# - Verifies installation
# - Falls back to bundled PKG if needed
# - Logs activity to /var/log/jamf_connect_install.log
#
# Intended use:
# - Run as a post-install script in a custom PKG
# - Fallback PKG must exist at:
#   /private/tmp/JamfConnectLogin-3.3.0.pkg

set -u

# =========================
# Configuration
# =========================

VENDOR_DMG="JamfConnect.dmg"
VENDOR_CDR="JamfConnect.cdr"
TMP_PATH="/private/tmp"
DMG_URL="https://files.jamfconnect.com/${VENDOR_DMG}"

WORK_PKG="${TMP_PATH}/JamfConnect.pkg"
FALLBACK_PKG="/private/tmp/JamfConnectLogin-3.3.0.pkg"

LOGFILE="/var/log/jamf_connect_install.log"

# Installation validation criteria
JC_SUPPORT_DIR="/Library/Application Support/JamfConnect"
JC_BIN_CANDIDATES=(
  "/usr/local/bin/authchanger"
  "/usr/local/bin/jamfconnect"
)

# Jamf target mount (passed as $3 if applicable)
TARGET_MOUNT="${3:-/}"

# =========================
# Helper Functions
# =========================

log() {
  printf "%s %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" | tee -a "$LOGFILE"
}

cleanup_attach() {
  if [[ -n "${MOUNT_POINT:-}" && -d "${MOUNT_POINT}" ]]; then
    log "Detaching ${MOUNT_POINT}"
    /usr/bin/hdiutil detach "${MOUNT_POINT}" -quiet || \
      log "Warning: failed to detach ${MOUNT_POINT}"
  fi

  rm -f "${TMP_PATH}/${VENDOR_CDR}" "${TMP_PATH}/${VENDOR_DMG}" >/dev/null 2>&1
}

check_installed() {
  [[ -d "$JC_SUPPORT_DIR" ]] || return 1

  for candidate in "${JC_BIN_CANDIDATES[@]}"; do
    [[ -x "$candidate" ]] && return 0
  done

  if find /usr/local/bin -maxdepth 1 -type f -executable -iname "*jamf*" -print -quit 2>/dev/null | grep -q .; then
    return 0
  fi

  return 1
}

install_pkg() {
  local pkg="$1"

  [[ -f "$pkg" ]] || {
    log "Installer not found at: $pkg"
    return 2
  }

  log "Installing package: $pkg (target: $TARGET_MOUNT)"
  /usr/sbin/installer -pkg "$pkg" -target "$TARGET_MOUNT" >>"$LOGFILE" 2>&1
  local rc=$?

  [[ $rc -eq 0 ]] && \
    log "Installer completed successfully" || \
    log "Installer failed with exit code $rc"

  return $rc
}

# =========================
# Main
# =========================

log "=== Starting Jamf Connect install sequence ==="

log "Downloading ${DMG_URL}"
/usr/bin/curl -L --silent --show-error --fail "${DMG_URL}" \
  -o "${TMP_PATH}/${VENDOR_DMG}" || \
  log "Warning: DMG download failed"

if [[ -f "${TMP_PATH}/${VENDOR_DMG}" ]]; then
  log "Converting DMG to CDR"
  /usr/bin/hdiutil convert -quiet "${TMP_PATH}/${VENDOR_DMG}" \
    -format UDTO -o "${TMP_PATH}/${VENDOR_CDR}" || \
    log "Warning: DMG conversion failed"

  log "Attaching CDR"
  /usr/bin/hdiutil attach "${TMP_PATH}/${VENDOR_CDR}" \
    -nobrowse -quiet || \
    log "Warning: DMG attach failed"

  MOUNT_PKG_PATH=$(find /Volumes -maxdepth 3 -type f \
    -name "JamfConnectLogin.pkg" -print -quit 2>/dev/null || true)

  if [[ -n "$MOUNT_PKG_PATH" ]]; then
    log "Found installer at $MOUNT_PKG_PATH"
    cp -R "$MOUNT_PKG_PATH" "$WORK_PKG" && \
      log "Copied installer to $WORK_PKG" || \
      log "Error copying installer"

    MOUNT_POINT=$(dirname "$MOUNT_PKG_PATH")
  else
    log "JamfConnectLogin.pkg not found in mounted volumes"
  fi

  cleanup_attach
else
  log "DMG not available; skipping DMG install path"
fi

if [[ -f "$WORK_PKG" ]]; then
  install_pkg "$WORK_PKG"
  rm -f "$WORK_PKG"
fi

if check_installed; then
  log "Jamf Connect installation verified"
  log "=== Finished: success ==="
  exit 0
fi

log "Verification failed after DMG install"

if [[ -f "$FALLBACK_PKG" ]]; then
  log "Attempting fallback installer"
  install_pkg "$FALLBACK_PKG"

  if check_installed; then
    log "Jamf Connect installed successfully via fallback"
    log "=== Finished: success (fallback) ==="
    exit 0
  fi
fi

log "Jamf Connect installation failed"
log "=== Finished: failure ==="
exit 1
