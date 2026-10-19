#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

cd "$(dirname "$0")"

lb clean --purge || true

lb config \
    --mode debian \
    --distribution trixie \
    --architecture amd64 \
    --binary-image iso-hybrid \
    --archive-areas "main contrib non-free-firmware" \
    --bootappend-live "boot=live components username=cutefish hostname=cutefish"

lb build

ISO="live-image-amd64.hybrid.iso"
if [[ ! -f "$ISO" ]]; then
    echo "Expected ISO was not produced: $ISO" >&2
    exit 1
fi

NAME="${1:-cutefish-debian-13-amd64}"
mv "$ISO" "$NAME.iso"
if [[ -f live-image-amd64.packages ]]; then
    mv live-image-amd64.packages "$NAME.packages"
fi
