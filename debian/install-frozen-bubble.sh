#!/usr/bin/env bash
# Debian/Ubuntu: install Frozen Bubble if needed and print ball GIF paths.
# Usage: bash install-frozen-bubble.sh
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
command -v apt-get >/dev/null && command -v dpkg-query >/dev/null ||
    fail 'This script requires Debian/Ubuntu with apt-get and dpkg-query.'

installed() {
    [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]
}

missing=()
for package in frozen-bubble frozen-bubble-data; do
    if ! installed "$package"; then
        missing+=("$package")
    fi
done

if ((${#missing[@]})); then
    elevate=()
    if ((EUID != 0)); then
        command -v sudo >/dev/null || fail 'Install sudo or run this script as root.'
        elevate=(sudo)
    fi
    # apt downloads packages (or reuses cached downloads) and installs dependencies.
    # Keep installation output on stderr; stdout contains only discovered paths.
    "${elevate[@]}" apt-get update >&2
    "${elevate[@]}" apt-get install -y "${missing[@]}" >&2
fi

for package in frozen-bubble frozen-bubble-data; do
    installed "$package" || fail "Package installation incomplete: $package"
done

# Query the actual installed manifest, not an assumed asset location.
manifest=$(dpkg-query -L frozen-bubble frozen-bubble-data)
assets=()
while IFS= read -r path; do
    case "$path" in
        */balls/*.gif)
            [[ -f "$path" ]] && assets+=("$path")
            ;;
    esac
done <<< "$manifest"

((${#assets[@]})) || fail 'No installed ball GIFs found; the data package may be damaged.'
printf '%s\n' "${assets[@]}" | LC_ALL=C sort -u
