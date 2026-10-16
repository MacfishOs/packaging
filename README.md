# packaging

Distribution packaging for the Cutefish desktop. The project repositories carry
no packaging of their own; it all lives here.

- `versions` lists each project's upstream version.
- `debian/<project>/debian/` is the `debian/` directory of that project's
  Debian source package.
- `arch/` will hold the Arch Linux PKGBUILDs.

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
Source and binary packages land in `out/debian/`.

## Releasing a version

Change the project's line in `versions` and add a matching entry to its
`debian/changelog` with `dch`.

## License

Each package's licence is in its `debian/copyright`.
