# packaging

Distribution packaging for the Cutefish desktop. The project repositories carry
no packaging of their own; it all lives here.

- `versions` lists each project's upstream version.
- `debian/<project>/debian/` is the `debian/` directory of that project's
  Debian source package.
- `arch/` will hold the Arch Linux PKGBUILDs.
- `iso/` is the live-build configuration of the Debian 13 live ISO.

## Debian

Check out the projects next to this repository, under their repository names:

```
cutefish-framework/
cutefish-core/
...
packaging/
```

Install the build tools, then build:

```shell
sudo apt install devscripts equivs --no-install-recommends
debian/build.sh --install               # every package, in dependency order
debian/build.sh cutefish-core settings  # just these
```

Packages are built in the order of the Build-Depends and Depends in their
control files. With `--install`, each package's build dependencies are
installed first and the package itself afterwards, so the next one can build
against it; without it, those must already be installed.

Each package is built from its checkout's committed HEAD, as a
`3.0 (quilt)` source package with a `.orig.tar.xz` exported by `git archive`.
A `debian/<project>/vendor` file names untracked trees of the checkout that go
into that tarball as well, such as the Skia sources cutefish-toolkit's
`scripts/fetch-skia.sh` fetches; a line starting with `!` leaves a path out.
Source and binary packages land in `out/debian/`. With `--snapshot`, each
package is versioned after its checkout's commit, such as
`1.0~git20261020120000.1a2b3c4-1`. The `~` puts snapshots before the release
in `versions`, so it should name the next release, not the last one.

`debian/publish.sh trixie-nightly repo/` lays those packages out as the
`trixie-nightly` suite of an APT repository under `repo/`; `--sign` signs it
with the default GnuPG key.

## APT repository

CI builds snapshots of every package each night and publishes them:

```
sudo curl -fsSLo /etc/apt/keyrings/cutefish.asc https://deb.cutefish.org/cutefish.asc
echo "deb [signed-by=/etc/apt/keyrings/cutefish.asc] https://deb.cutefish.org trixie-nightly main" \
  | sudo tee /etc/apt/sources.list.d/cutefish.list
sudo apt update
sudo apt install cutefish-desktop
```

## ISO

The ISO installs `cutefish-desktop` from deb.cutefish.org. CI builds it after
each package publish; to build it locally, as root:

```shell
iso/build.sh
```

## Releasing a version

Change the project's line in `versions` and add a matching entry to its
`debian/changelog` with `dch`.

## License

Each package's licence is in its `debian/copyright`.
