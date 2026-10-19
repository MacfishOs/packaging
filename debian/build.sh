#!/usr/bin/env bash
# Builds Debian source and binary packages from the project checkouts next to
# this repository. Packages are built in dependency order, taken from the
# Build-Depends and Depends in their control files. Each package is built from
# its checkout's committed HEAD; the results go to out/debian/. A native
# package, such as the cutefish-desktop metapackage, has no checkout and is
# built from its packaging alone.
#
#   debian/build.sh                            # every package
#   debian/build.sh cutefish-core settings     # just these
#   debian/build.sh --install                  # every package, each installed
#                                              # before the ones that need it
#   debian/build.sh --snapshot                 # versioned after the commit,
#                                              # e.g. 0.1.0+git20261020120000.1a2b3c4-1
set -Eeuo pipefail

PACKAGING="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$(dirname "$PACKAGING")"
OUT="$PACKAGING/out/debian"

INSTALL=false
SNAPSHOT=false
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --install) INSTALL=true ;;
    --snapshot) SNAPSHOT=true ;;
    *) echo "Error: unknown option $1" >&2; exit 1 ;;
  esac
  shift
done

SUDO=(sudo)
if (( EUID == 0 )); then
  SUDO=()
fi

ALL=()
declare -A VERSIONS=()
while read -r project version; do
  [[ -z "$project" || "$project" == \#* ]] && continue
  ALL+=("$project")
  VERSIONS[$project]="$version"
done < "$PACKAGING/versions"

for name in "$@"; do
  [[ -n "${VERSIONS[$name]:-}" ]] || { echo "Error: $name is not in versions" >&2; exit 1; }
done

# Which project builds each binary package.
declare -A OWNER=()
for project in "${ALL[@]}"; do
  while read -r package; do
    OWNER[$package]="$project"
  done < <(awk '/^Package:/ { print $2 }' "$PACKAGING/debian/$project/debian/control")
done

# The other projects a project's control file names in its build or runtime
# dependencies.
dependencies() {
  local word
  awk '/^[A-Za-z-]+:/ { field = ($1 == "Build-Depends:" || $1 == "Build-Depends-Indep:" || $1 == "Depends:") }
       field { sub(/^[A-Za-z-]+:/, ""); gsub(/\([^)]*\)|\[[^]]*\]|<[^>]*>|[,|]/, " "); print }' \
    "$PACKAGING/debian/$1/debian/control" \
    | tr -s ' \t' '\n' | while read -r word; do
        [[ -n "$word" && -n "${OWNER[$word]:-}" && "${OWNER[$word]}" != "$1" ]] && echo "${OWNER[$word]}"
      done | sort -u
}

# Depth-first, so a project comes after everything it depends on; ties keep
# the order of the versions file.
ORDER=()
declare -A STATE=()
visit() {
  local project="$1" dependency
  [[ "${STATE[$project]:-}" == done ]] && return
  if [[ "${STATE[$project]:-}" == visiting ]]; then
    echo "Error: dependency cycle through $project" >&2
    exit 1
  fi
  STATE[$project]=visiting
  for dependency in $(dependencies "$project"); do
    visit "$dependency"
  done
  STATE[$project]=done
  ORDER+=("$project")
}
for project in "${ALL[@]}"; do
  visit "$project"
done

PROJECTS=()
for project in "${ORDER[@]}"; do
  if (( $# == 0 )) || [[ " $* " == *" $project "* ]]; then
    PROJECTS+=("$project")
  fi
done

echo "Build order: ${PROJECTS[*]}"

if [[ "$INSTALL" == true ]]; then
  command -v mk-build-deps >/dev/null && dpkg -s equivs >/dev/null 2>&1 \
    || { echo "Error: --install needs devscripts and equivs" >&2; exit 1; }
  "${SUDO[@]}" true
fi

mkdir -p "$OUT"

# Installs the binary packages just built for $source $version.
install_built() {
  [[ "$INSTALL" == true ]] || return 0
  local debs=() deb
  while read -r deb; do
    [[ "$deb" == *-dbgsym_* ]] || debs+=("$deb")
  done < <(dcmd --deb "$OUT/${source}_${version}_$(dpkg-architecture -qDEB_HOST_ARCH).changes")
  "${SUDO[@]}" apt-get install --yes --reinstall "${debs[@]}"
}

for project in "${PROJECTS[@]}"; do
  src="$SOURCES/$project"
  packaging="$PACKAGING/debian/$project/debian"
  changelog="$packaging/changelog"

  native=false
  if [[ "$(cat "$packaging/source/format" 2>/dev/null)" == "3.0 (native)" ]]; then
    native=true
  fi

  if [[ "$native" == false ]] && ! git -C "$src" rev-parse --verify --quiet HEAD >/dev/null; then
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

  if [[ "$SNAPSHOT" == true && "$native" == false ]]; then
    stamp="$(TZ=UTC0 git -C "$src" log -1 --date=format-local:%Y%m%d%H%M%S --format=%cd HEAD)"
    upstream="$upstream+git$stamp.$(git -C "$src" rev-parse --short=7 HEAD)"
    version="$upstream-${version##*-}"
  fi

  echo
  echo "==> [$project] $source $version"

  if [[ "$INSTALL" == true ]]; then
    (cd "$OUT" && "${SUDO[@]}" mk-build-deps -i -r \
      -t "apt-get --yes --no-install-recommends" "$packaging/control")
  fi

  if [[ "$native" == true ]]; then
    tree="$OUT/$source-$version"
    rm -rf "$tree"
    mkdir -p "$tree"
    cp -a "$packaging" "$tree/debian"
    (cd "$tree" && dpkg-buildpackage -us -uc)
    rm -rf "$tree"
    install_built
    echo "==> [$project] OK"
    continue
  fi

  tree="$OUT/$source-$upstream"
  rm -rf "$tree"
  git -C "$src" archive --prefix="$source-$upstream/" -o "$OUT/${source}_$upstream.orig.tar" HEAD
  # Trees the project fetches rather than tracks, such as a pinned library's
  # sources, are taken from the checkout's working tree.
  vendor="$PACKAGING/debian/$project/vendor"
  if [[ -f "$vendor" ]]; then
    paths=()
    excludes=(--exclude=.git)
    while read -r path; do
      [[ -z "$path" || "$path" == \#* ]] && continue
      if [[ "$path" == !* ]]; then
        excludes+=("--exclude=${path#!}")
      elif [[ -d "$src/$path" ]]; then
        paths+=("$path")
      else
        echo "Error: $src/$path is missing; fetch it first" >&2
        exit 1
      fi
    done < "$vendor"
    tar -rf "$OUT/${source}_$upstream.orig.tar" -C "$src" "${excludes[@]}" \
      --owner=0 --group=0 --numeric-owner --transform="s|^|$source-$upstream/|" "${paths[@]}"
  fi
  xz -T0 -f "$OUT/${source}_$upstream.orig.tar"
  tar -xf "$OUT/${source}_$upstream.orig.tar.xz" -C "$OUT"
  # An older commit may still carry its own debian/.
  rm -rf "$tree/debian"
  cp -a "$packaging" "$tree/debian"
  if [[ "$SNAPSHOT" == true ]]; then
    (cd "$tree" && DEBEMAIL="$(dpkg-parsechangelog -S Maintainer)" \
      dch --newversion "$version" --distribution UNRELEASED "Snapshot of commit $(git -C "$src" rev-parse HEAD).")
  fi

  (cd "$tree" && dpkg-buildpackage -us -uc)
  rm -rf "$tree"
  install_built

  echo "==> [$project] OK"
done
