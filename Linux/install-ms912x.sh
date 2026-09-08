#!/usr/bin/env bash
#
# install-ms912x.sh — Reproducible installer for the MacroSilicon MS912x
# USB-to-VGA/HDMI adapter (VID/PID 534d:6021, 534d:0821) on Linux.
#
# Tested on Arch Linux with GNOME (kernel 7.2.x). The driver is built and
# registered with DKMS, so it survives kernel upgrades and the same script
# can be re-run on any other host.
#
# Usage:
#   sudo ./install-ms912x.sh
#
# Environment overrides (optional):
#   MS912X_REPO=...   git URL of the ms912x driver (default: rhgndf/ms912x)
#   MS912X_DIR=...    install directory (default: /opt/ms912x)
#
# Note: this script installs the open-source ms912x DRM driver, which covers
# the MS912x family. Adapters based on MS913x (VID/PID 345f:9132/9133/9135)
# require the official MacroSilicon driver and are detected but skipped.
set -euo pipefail

REPO_URL="${MS912X_REPO:-https://github.com/rhgndf/ms912x.git}"
INSTALL_DIR="${MS912X_DIR:-/opt/ms912x}"
MODULE="ms912x"
DKMS_NAME="ms912x/0.1"

KERNEL="$(uname -r)"
KVER="${KERNEL%%-*}"
MAJOR="${KVER%%.*}"
MINOR="${KVER#*.}"
MINOR="${MINOR%%.*}"

log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
die()  { echo -e "\033[1;31m[x] $*\033[0m" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -n "$MAJOR" && -n "$MINOR" ]] || die "Could not parse kernel version: $KERNEL"

# ---------------------------------------------------------------------------
# 1. Install build prerequisites (distro-aware)
# ---------------------------------------------------------------------------
install_prereqs() {
    if command -v pacman >/dev/null 2>&1; then
        pacman -Sy --needed --noconfirm linux-headers dkms base-devel git
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "kernel-devel-${KERNEL}" dkms gcc make git
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y "linux-headers-${KERNEL}" dkms build-essential git
    else
        warn "Unknown package manager. Install kernel headers + dkms + git manually."
    fi
    [[ -d "/lib/modules/${KERNEL}/build" ]] || \
        die "Kernel headers for ${KERNEL} not found. Install the matching linux-headers package."
}

# ---------------------------------------------------------------------------
# 2. Pick the driver branch that matches the running kernel
# ---------------------------------------------------------------------------
pick_branch() {
    local target="kernel-${MAJOR}.${MINOR}"
    local heads branch
    heads="$(git ls-remote --heads "$REPO_URL" | sed 's#.*refs/heads/##')"

    if grep -qx "$target" <<<"$heads"; then
        echo "$target"
    elif branch="$(printf '%s\n' "$heads" | grep -E "^kernel-${MAJOR}\." | sort -V | tail -n1)"; [[ -n "$branch" ]]; then
        echo "$branch"
    else
        echo "main"
    fi
}

# ---------------------------------------------------------------------------
# 3. Adapter detection (informational)
# ---------------------------------------------------------------------------
detect_adapter() {
    local ids
    ids="$(lsusb 2>/dev/null | grep -iE "534d|345f" || true)"
    if grep -qiE "534d" <<<"$ids"; then
        log "MS912x adapter detected: $(grep -i 534d <<<"$ids")"
    elif grep -qiE "345f" <<<"$ids"; then
        warn "MS913x adapter detected ($(grep -i 345f <<<"$ids"))."
        warn "The MS913x chips need the official MacroSilicon driver, NOT this one."
    else
        warn "No MacroSilicon adapter currently connected — the module will be"
        warn "installed and will bind automatically when the adapter is plugged in."
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
log "Kernel: ${KERNEL} (major.minor = ${MAJOR}.${MINOR})"
install_prereqs
detect_adapter

BRANCH="$(pick_branch)"
log "Driver branch: ${BRANCH}"

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
else
    git -C "$INSTALL_DIR" fetch --all --prune
    git -C "$INSTALL_DIR" checkout -f "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only
fi

log "Building and installing with DKMS (this may take a while)..."
dkms remove "$DKMS_NAME" --all 2>/dev/null || true
( cd "$INSTALL_DIR" && dkms install . )

log "Loading module and enabling it at boot..."
modprobe "$MODULE" 2>/dev/null || true
grep -qx "$MODULE" /etc/modules-load.d/ms912x.conf 2>/dev/null || \
    echo "$MODULE" > /etc/modules-load.d/ms912x.conf

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo
log "Verification:"
dkms status | grep "$DKMS_NAME" || warn "DKMS status: ${DKMS_NAME} not found"
lsmod | grep "$MODULE" || warn "module ${MODULE} is not loaded"
for d in /sys/class/drm/card*/card*-*; do
    [[ -e "$d/status" ]] || continue
    printf '  %-24s %-11s %s\n' "${d##*/}" "$(cat "$d/status")" "$(head -n1 "$d/modes" 2>/dev/null)"
done

echo
cat <<'EOF'
Post-install notes
------------------
1. Configure the new output in Settings -> Displays (mirror or extend).
   On GNOME Wayland, re-login if the output does not appear immediately.

2. If the external display glitches in extended mode, use a resolution that
   is a multiple of 16 pixels (the driver updates the framebuffer in 16px
   blocks). Example: replace 1366x768 with 1280x720@60.

3. If the mouse cursor is invisible on the external display under GNOME
   Wayland (no cursor plane in this driver), either change the cursor size
   (Accessibility -> Cursor) or use the "GNOME on Xorg" session.

4. The module is registered with DKMS (AUTOINSTALL=yes): after a kernel
   upgrade just reboot, or run: sudo dkms autoinstall
EOF