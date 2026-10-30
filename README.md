# freedomnas-overlay

Gentoo ebuilds for [FreedomNAS](https://codeberg.org/FreedomNAS) — the
OS-agnostic storage appliance. Everything lives in a dedicated `app-nas`
category, because these packages are one appliance rather than four
unrelated tools.

| Package | What it installs |
|---------|------------------|
| `app-nas/freedomnas-profiles` | The JSON translator layer + boot-chain assets → `/usr/lib/freedomnas/profiles` |
| `app-nas/freedomnas-core` | Engine, config manager, reconciler → `/usr/lib/freedomnas/core` + `freedomnas` CLI |
| `app-nas/freedomnas-docs` | The documentation, built for offline reading → `/usr/lib/freedomnas/docs`, served by the WebUI at `/docs/` |
| `app-nas/freedomnas-webui` | FastAPI backend and Jinja2 frontend → `/usr/lib/freedomnas/webui`; depends on `freedomnas-docs` |
| `app-nas/freedomnas-installer` | Provisioning tool → `freedomnas-install` |
| `app-nas/freedomnas-module-containers` | The containers community module (Docker on ZFS datasets, apps, catalogue) → `/usr/lib/freedomnas/modules/containers` and `/usr/lib/freedomnas/profiles/containers`; live ebuild only until the module has a release |
| `app-nas/freedomnas-module-proxy` | The reverse proxy community module (Caddy, HTTPS for every web app) → `/usr/lib/freedomnas/modules/proxy` and `/usr/lib/freedomnas/profiles/proxy`; live ebuild only until the module has a release |
| `app-nas/freedomnas` | Meta package pulling the stack together |

### Bootstrap tools for the pacman-based editions

These let a Gentoo host — the FreedomNAS live ISO in particular — install
the Arch and Artix editions with `pacstrap` instead of a rootfs tarball.
They are ordinary versioned ebuilds, keyworded `~amd64`.

| Package | What it installs |
|---------|------------------|
| `sys-apps/pacman` | pacman, `pacman-key`, libalpm. Scriptlet shell and `ldconfig` point at the paths of the Arch/Artix root being installed |
| `sys-apps/arch-install-scripts` | `pacstrap` and `genfstab`; `arch-chroot` comes from `::gentoo`'s `sys-apps/arch-chroot` |
| `app-crypt/archlinux-keyring` | `/usr/share/pacman/keyrings/archlinux*`, repackaged from `archive.archlinux.org` |
| `app-crypt/artix-keyring` | `/usr/share/pacman/keyrings/artix*`, repackaged from `archive.artixlinux.org` |

A keyring is only as current as its ebuild: packages signed by a key added
upstream after that version fail verification until the ebuild is bumped.

### MkDocs, to build freedomnas-docs

MkDocs left `::gentoo`, so the overlay carries it and what it needs that the
tree no longer has, for Python 3.11 to 3.14. They are ordinary versioned
ebuilds, keyworded `~amd64`, with their original headers.

| Package | Why |
|---------|-----|
| `dev-python/mkdocs` | builds the documentation |
| `dev-python/mkdocs-material` | its theme (`USE=social` for the social cards, not needed here) |
| `dev-python/mkdocs-material-extensions` | pulled in by mkdocs-material |
| `dev-python/mkdocs-get-deps`, `ghp-import`, `mergedeep`, `pyyaml-env-tag` | mkdocs' dependencies |
| `dev-python/paginate`, `readtime` | mkdocs-material's dependencies |

## Adding the overlay

With `eselect repository`:

```sh
eselect repository add freedomnas git https://codeberg.org/FreedomNAS/freedomnas-overlay.git
emaint sync --repo freedomnas
```

Or by hand, in `/etc/portage/repos.conf/freedomnas.conf`:

```ini
[freedomnas]
location = /var/db/repos/freedomnas
sync-type = git
sync-uri = https://codeberg.org/FreedomNAS/freedomnas-overlay.git
auto-sync = yes
masters = gentoo
```

## Installing

Each FreedomNAS package comes in two forms:

| Version | Source | Keywords |
|---------|--------|----------|
| `X.Y.Z` (release) | the `vX.Y.Z` tag, as Codeberg's archive tarball | `~amd64` |
| `9999` (live) | the `dev` branch, with git | none |

Pick one in `/etc/portage/package.accept_keywords` — the releases:

```
app-nas/*::freedomnas ~amd64
*/*::freedomnas ~amd64
```

or `dev`, with `app-nas/*::freedomnas **` as the first line. The second
line accepts the MkDocs packages `freedomnas-docs` is built with. The
FreedomNAS installer writes exactly this, from the channel it installs
(`/etc/portage/package.accept_keywords/freedomnas-channel`).

Then:

```sh
emerge --ask app-nas/freedomnas                    # core + profiles + WebUI
emerge --ask --newuse app-nas/freedomnas[installer] # also the provisioning tool
```

## USE flags

`app-nas/freedomnas`

| Flag | Default | Effect |
|------|---------|--------|
| `webui` | on | Install the web interface |
| `installer` | off | Install `freedomnas-install`, so this machine can provision others |

`app-nas/freedomnas-webui`

| Flag | Default | Effect |
|------|---------|--------|
| `cron` | on | Start the WebUI at boot via a cron `@reboot` hook |
| `openrc` | off | Install an OpenRC service instead |

The two are mutually exclusive (`REQUIRED_USE`) — enabling both would start
the WebUI twice.

**The cron hook is the canonical path**, not a fallback: FreedomNAS starts
its WebUI the same way on systemd, OpenRC, runit, s6, dinit and bsd\_rc, which
is what lets one image and one installer serve every edition (see ADR-002 in
the main repository). `USE=openrc` exists because a Gentoo system may prefer
to manage the service the way it manages everything else; it is a local
convenience, and nothing else in the project depends on it.

## Releases

A release adds `<name>-X.Y.Z.ebuild` for the `app-nas` packages, a copy
of the `9999` ebuild (one file serves both forms: `PV` decides between
git and the tarball), and its Manifest. Nobody writes them by hand: the
`autobump` workflow (`.forgejo/workflows/autobump.yml`) runs every night
and does it for every package in `.forgejo/autobump/packages.json`.

| Packages | Follow | A new version |
|----------|--------|---------------|
| the six FreedomNAS components, the community modules | the `vX.Y.Z` tags of their Codeberg repository | a copy of `9999`; the two newest releases stay |
| `topgrade-bin`, the Arch and Artix keyrings, `arch-install-scripts`, the MkDocs stack | their upstream's releases (GitHub, the Arch/Artix archives, GitLab tags, PyPI) | a copy of the newest ebuild, which it replaces |

Each bump regenerates the Manifest, must leave `pkgcheck` with
nothing the package did not already report (and get through
`ebuild … prepare` where `packages.json` says `"prepare": true`), and is
committed to `main` on its own. One that fails opens an issue instead.
`sys-apps/pacman` is not followed: its tarball's URL holds a GitLab upload
hash, so it is bumped by hand.

The workflow needs the secret `AUTOBUMP_TOKEN`, a Codeberg access token with
the scopes `write:repository` and `write:issue`. Locally:

```sh
.forgejo/autobump/autobump.py --check            # what is outdated
.forgejo/autobump/autobump.py app-nas/freedomnas-core   # bump and commit, no push
```

## Notes for packagers

`freedomnas-core` is deliberately **not** built with `distutils-r1`. Upstream
ships no `setup.py` and no `[project]` table — the modules are a plain package
directory installed under `/usr/lib/freedomnas/core/` and put on `sys.path`
with a `.pth` file. That is the layout `ARCHITECTURE.md` defines, and the one
the image builder and the installer both produce; a build system would only
fight it.

`freedomnas-webui` symlinks `bin/firstboot.sh` and `bin/supervisor.sh` into
`freedomnas-profiles`' assets rather than shipping copies, so the boot-time
scripts cannot drift from the ones baked into the images.

## License

GPL-2.0-or-later: the GNU General Public License, version 2 or (at your
option) any later version. The text of version 2 is in `LICENSE`.

The packages the ebuilds install keep their own licenses — MPL-2.0 for the
FreedomNAS components, as each ebuild's `LICENSE` says.
