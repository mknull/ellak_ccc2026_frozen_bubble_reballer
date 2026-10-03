#!/usr/bin/env bash
# CachyOS/Arch Linux: install Frozen Bubble if needed and print ball GIF paths.
# Usage: bash install-frozen-bubble.sh
set -euo pipefail
if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then
    cat <<HELP
Usage: ${0##*/}

Install Frozen Bubble if missing on CachyOS/Arch Linux and print the full
paths of installed ball GIFs (including colourblind variants).
Miniature PNGs are not included in this listing.

Requires pacman. Uses sudo for repository installation, or an existing paru/yay
for AUR installation if the package is absent from configured repositories.
Run as your normal user. Package-manager prompts remain enabled.
Keep your system updated before installation; this script does not refresh databases.
Package installation messages go to stderr; asset paths go to stdout.
HELP
    exit 0
fi
if (( $# )); then
    printf 'Usage: %s [--help]\n' "${0##*/}" >&2
    exit 2
fi

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
command -v pacman >/dev/null || fail 'This script requires CachyOS/Arch Linux with pacman.'

if ! pacman -Q frozen-bubble >/dev/null 2>&1; then
    if pacman -Si frozen-bubble >/dev/null 2>&1; then
        elevate=()
        if ((EUID != 0)); then
            command -v sudo >/dev/null || fail 'Install sudo or run this script as root.'
            elevate=(sudo)
        fi
        "${elevate[@]}" pacman -S --needed frozen-bubble >&2
    else
        # AUR builds must run as the normal user, not root.
        ((EUID != 0)) || fail 'Not found in configured repositories. Rerun as your normal user to use an AUR helper.'
        helper=''
        for candidate in paru yay; do
            if command -v "$candidate" >/dev/null; then
                helper=$candidate
                break
            fi
        done
        [[ -n $helper ]] || fail 'Not found in configured repositories. Install an AUR helper (paru or yay), then rerun, or install frozen-bubble manually.'
        "$helper" -S --needed frozen-bubble >&2
    fi
fi
pacman -Q frozen-bubble >/dev/null 2>&1 || fail 'Frozen Bubble installation incomplete.'

# Query the actual installed manifest, not an assumed asset location.
manifest=$(pacman -Qlq frozen-bubble)
assets=()
while IFS= read -r path; do
    case "$path" in
        */balls/*.gif)
            [[ -f "$path" ]] && assets+=("$path")
            ;;
    esac
done <<< "$manifest"

((${#assets[@]})) || fail 'No installed ball GIFs found; the package may be damaged.'
printf '%s\n' "${assets[@]}" | LC_ALL=C sort -u
