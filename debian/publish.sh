#!/usr/bin/env bash
# Lays out the packages in out/debian/ as one suite of an APT repository and
# writes its indexes. Each suite keeps its own pool, so a suite can be
# replaced on the server without touching the others:
#
#   debian/publish.sh trixie-nightly repo/          # repo/dists/trixie-nightly
#                                                   # repo/pool/trixie-nightly
#   debian/publish.sh --sign trixie-nightly repo/   # signed with the default
#                                                   # GnuPG secret key
set -Eeuo pipefail

PACKAGING="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PACKAGING/out/debian"

SIGN=false
if [[ "${1:-}" == "--sign" ]]; then
  SIGN=true
  shift
fi

if (( $# != 2 )); then
  echo "Usage: debian/publish.sh [--sign] SUITE DIRECTORY" >&2
  exit 1
fi
SUITE="$1"
mkdir -p "$2"
ROOT="$(cd "$2" && pwd)"

pool="pool/$SUITE/main"
dists="dists/$SUITE"
rm -rf "${ROOT:?}/pool/$SUITE" "${ROOT:?}/$dists"
mkdir -p "$ROOT/$pool" "$ROOT/$dists/main/binary-amd64" "$ROOT/$dists/main/source"

shopt -s nullglob
changes=("$OUT"/*.changes)
if (( ${#changes[@]} == 0 )); then
  echo "Error: no packages in $OUT; run debian/build.sh first" >&2
  exit 1
fi

for file in "${changes[@]}"; do
  source="$(sed -n 's/^Source: //p' "$file")"
  mkdir -p "$ROOT/$pool/$source"
  while read -r path; do
    # Debug symbols stay out of the repository.
    [[ "$path" == *-dbgsym_* ]] || cp "$path" "$ROOT/$pool/$source/"
  done < <(dcmd --no-changes --no-buildinfo "$file")
done

cd "$ROOT"
apt-ftparchive packages "$pool" > "$dists/main/binary-amd64/Packages"
apt-ftparchive sources "$pool" > "$dists/main/source/Sources"
for index in "$dists/main/binary-amd64/Packages" "$dists/main/source/Sources"; do
  xz -k -f "$index"
  gzip -k -f -n "$index"
done

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=Cutefish \
  -o APT::FTPArchive::Release::Label=Cutefish \
  -o APT::FTPArchive::Release::Suite="$SUITE" \
  -o APT::FTPArchive::Release::Codename="$SUITE" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  -o APT::FTPArchive::Release::Components=main \
  -o APT::FTPArchive::Release::Acquire-By-Hash=no \
  release "$dists" > "$ROOT/Release.tmp"
mv "$ROOT/Release.tmp" "$dists/Release"

if [[ "$SIGN" == true ]]; then
  gpg --batch --yes --clearsign -o "$dists/InRelease" "$dists/Release"
  gpg --batch --yes --armor --detach-sign -o "$dists/Release.gpg" "$dists/Release"
  gpg --batch --yes --armor --export -o "$ROOT/cutefish.asc"
fi

echo "==> $SUITE: $(find "$pool" -name '*.deb' | wc -l) packages in $ROOT"
