#!/usr/bin/env bash
# Writes the index pages of download.cutefish.org to standard output:
#
#   web/index.sh root                       # the repository's front page
#   web/index.sh iso NAME SIZE SHA256       # iso/nightly/, for NAME.iso
set -Eeuo pipefail

FINGERPRINT="5F52 7F0C B976 4BA0 AF99  BAE5 F4A4 30BC 9E10 91A7"
BLOG="https://cutefish.org/blog/how-cutefish-is-built/"

header() {
  cat << EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$1</title>
<style>
:root {
  color-scheme: light dark;
  --background: #ffffff;
  --alternate-background: #f2f4f5;
  --text: #323238;
  --secondary-text: #64646e;
  --highlight: #3385ff;
  --separator: rgba(100, 100, 110, 0.1);
  font-family: "Noto Sans", system-ui, sans-serif;
  line-height: 1.7;
}
@media (prefers-color-scheme: dark) {
  :root {
    --background: #1c1c1d;
    --alternate-background: #3c3c3d;
    --text: #ffffff;
    --secondary-text: #888888;
    --separator: rgba(136, 136, 136, 0.3);
  }
}
body { margin: 0; background: var(--background); color: var(--text); -webkit-font-smoothing: antialiased; }
main { max-width: 640px; margin: 0 auto; padding: 48px 24px 64px; }
h1, h2 { font-weight: 600; line-height: 1.25; letter-spacing: -0.015em; }
h1 { font-size: 2rem; margin: 0 0 8px; }
h2 { font-size: 1.25rem; margin: 40px 0 8px; }
p { margin: 8px 0; }
.lead { color: var(--secondary-text); }
a { color: var(--highlight); text-decoration: none; }
a:hover { text-decoration: underline; }
pre { background: var(--alternate-background); border-radius: 10px; padding: 12px 16px; overflow-x: auto; font-size: 0.875rem; line-height: 1.6; }
code { font-family: ui-monospace, "Noto Sans Mono", monospace; }
.file { background: var(--alternate-background); border-radius: 10px; padding: 16px; margin: 16px 0; }
.file .name { font-weight: 600; word-break: break-all; }
.file .meta { color: var(--secondary-text); font-size: 0.875rem; }
.file .digest { font-family: ui-monospace, "Noto Sans Mono", monospace; font-size: 0.8125rem; word-break: break-all; }
footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--separator); color: var(--secondary-text); font-size: 0.875rem; }
</style>
</head>
<body>
<main>
EOF
}

footer() {
  cat << EOF
<footer>
Built and published by
<a href="https://github.com/cutefishos/packaging/actions">GitHub Actions</a>
from <a href="https://github.com/cutefishos/packaging">cutefishos/packaging</a>.
See <a href="$BLOG">how Cutefish packages are built</a> and
<a href="https://cutefish.org/blog/official-sources/">the official sources of Cutefish</a>.
</footer>
</main>
</body>
</html>
EOF
}

root() {
  header "Cutefish packages for Debian 13"
  cat << EOF
<h1>Cutefish packages for Debian 13</h1>
<p class="lead">The APT repository of Cutefish Desktop for Debian 13, and nightly
ISOs for testing. Nothing here is an official release yet.</p>

<h2>Nightly ISO</h2>
<p>The newest live ISO is in <a href="/iso/nightly/">iso/nightly</a>.</p>

<h2>Adding the repository</h2>
<p>For Debian 13 (trixie) on amd64. Download the key, check that its
fingerprint is the one below, and add the repository:</p>
<pre><code>sudo curl -fsSLo /etc/apt/keyrings/cutefish.asc https://download.cutefish.org/debian/cutefish.asc
gpg --show-keys /etc/apt/keyrings/cutefish.asc
echo "deb [signed-by=/etc/apt/keyrings/cutefish.asc] https://download.cutefish.org/debian trixie-nightly main" \\
  | sudo tee /etc/apt/sources.list.d/cutefish.list
sudo apt update
sudo apt install cutefish-desktop</code></pre>

<h2>Signing key</h2>
<pre><code>Cutefish Archive &lt;reionwong@gmail.com&gt;
ed25519, fingerprint $FINGERPRINT</code></pre>
<p>Only the build workflow can sign with it.</p>

<h2>What went into the packages</h2>
<p><a href="/debian/dists/trixie-nightly/commits">commits</a> lists the commit of every
project the newest build used, and
<a href="/debian/dists/trixie-nightly/SHA256SUMS">SHA256SUMS</a> the checksum of every
file it made. Each file also has a
<a href="https://github.com/cutefishos/packaging/attestations">build provenance attestation</a>.</p>
EOF
  footer
}

iso() {
  local name="$1" size="$2" digest="$3" built human
  built="$(date -u '+%B %-d, %Y, %H:%M UTC')"
  human="$(awk -v b="$size" 'BEGIN { printf "%.2f GB", b / 1e9 }')"

  header "Cutefish nightly ISO for Debian 13"
  cat << EOF
<h1>Cutefish nightly ISO for Debian 13</h1>
<p class="lead">The newest live ISO of Cutefish on Debian 13, built from the
latest code. It is meant for testing; only the newest one is kept.</p>

<div class="file">
<div class="name"><a href="$name.iso">$name.iso</a></div>
<div class="meta">$human &middot; built $built &middot;
<a href="$name.iso.sha256">SHA-256</a> &middot;
<a href="$name.packages">package list</a></div>
<div class="digest">$digest</div>
</div>

<h2>Checking the download</h2>
<p>Compare the checksum, then verify that the ISO was built by the Cutefish
workflow and not changed since, with the
<a href="https://cli.github.com/">GitHub CLI</a> 2.49 or later:</p>
<pre><code>sha256sum -c $name.iso.sha256
gh attestation verify $name.iso --repo cutefishos/packaging</code></pre>
<p><a href="LATEST">LATEST</a> always names the newest ISO, for scripts.</p>
EOF
  footer
}

case "${1:-}" in
  root) root ;;
  iso)
    (( $# == 4 )) || { echo "Usage: web/index.sh iso NAME SIZE SHA256" >&2; exit 1; }
    iso "$2" "$3" "$4"
    ;;
  *) echo "Usage: web/index.sh root | iso NAME SIZE SHA256" >&2; exit 1 ;;
esac
