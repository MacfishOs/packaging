#!/usr/bin/env bash
# Builds Debian source and binary packages from the project checkouts next to
# this repository, in the order of the versions file. Each package is built
# from its checkout's committed HEAD; the results go to out/debian/.
#
#   debian/build.sh                  # every package
#   debian/build.sh fishui settings  # just these, still in build order
set -Eeuo pipefail

PACKAGING="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$(dirname "$PACKAGING")"
OUT="$PACKAGING/out/debian"

PROJECTS=()
declare -A VERSIONS=()
while read -r project version; do
  [[ -z "$project" || "$project" == \#* ]] && continue
  PROJECTS+=("$project")
  VERSIONS[$project]="$version"
done < "$PACKAGING/versions"

if (( $# > 0 )); then
  for name in "$@"; do
    [[ -n "${VERSIONS[$name]:-}" ]] || { echo "Error: $name is not in versions" >&2; exit 1; }
  done
  selected=()
  for project in "${PROJECTS[@]}"; do
    [[ " $* " == *" $project "* ]] && selected+=("$project")
  done
  PROJECTS=("${selected[@]}")
fi

mkdir -p "$OUT"

for project in "${PROJECTS[@]}"; do
  src="$SOURCES/$project"
  packaging="$PACKAGING/debian/$project/debian"
  changelog="$packaging/changelog"

  if ! git -C "$src" rev-parse --verify --quiet HEAD >/dev/null; then
    echo "Error: $src is not a Git checkout with a commit" >&2
    exit 1
  fi

  source="$(dpkg-parsechangelog -l "$changelog" -S Source)"
  version="$(dpkg-parsechangelog -l "$changelog" -S Version)"
  upstream="${version%-*}"
  if [[ "$upstream" != "${VERSIONS[$project]}" ]]; then
    echo "Error: $project's changelog is at $version, versions says ${VERSIONS[$project]}" >&2
    exit 1
  fi

  echo
  echo "==> [$project] $source $version"

  tree="$OUT/$source-$upstream"
  rm -rf "$tree"
  git -C "$src" archive --prefix="$source-$upstream/" HEAD \
    | xz -T0 > "$OUT/${source}_$upstream.orig.tar.xz"
  tar -xf "$OUT/${source}_$upstream.orig.tar.xz" -C "$OUT"
  # An older commit may still carry its own debian/.
  rm -rf "$tree/debian"
  cp -a "$packaging" "$tree/debian"

  (cd "$tree" && dpkg-buildpackage -us -uc)
  rm -rf "$tree"

  echo "==> [$project] OK"
done
