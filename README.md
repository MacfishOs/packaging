# packaging

Distribution packaging for the Cutefish desktop. The project repositories carry
no packaging of their own; it all lives here.

- `versions` lists each project's upstream version, in build order.
- `debian/<project>/debian/` is the `debian/` directory of that project's
  Debian source package.
- `arch/` will hold the Arch Linux PKGBUILDs.

## Debian

Check out the projects next to this repository, under their repository names:

```
cutefish-framework/
fishui/
...
packaging/
```

Install the build tools, then build:

```shell
sudo apt install devscripts equivs --no-install-recommends
debian/build.sh                  # every package
debian/build.sh fishui settings  # just these
```

Each package is built from its checkout's committed HEAD, as a
`3.0 (quilt)` source package with a `.orig.tar.xz` exported by `git archive`.
Source and binary packages land in `out/debian/`.

A package builds against the packages before it in `versions`, so install
those first. To install one package's build dependencies:

```shell
sudo mk-build-deps -i -r -t "apt-get --yes" debian/fishui/debian/control
```

## Releasing a version

Change the project's line in `versions` and add a matching entry to its
`debian/changelog` with `dch`.

## License

Each package's licence is in its `debian/copyright`.
