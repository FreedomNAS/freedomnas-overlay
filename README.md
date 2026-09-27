# freedomnas-overlay

Gentoo ebuilds for [FreedomNAS](https://codeberg.org/FreedomNAS) — the
OS-agnostic storage appliance. Everything lives in a dedicated `app-nas`
category, because these packages are one appliance rather than four
unrelated tools.

| Package | What it installs |
|---------|------------------|
| `app-nas/freedomnas-profiles` | The JSON translator layer + boot-chain assets → `/usr/lib/freedomnas/profiles` |
| `app-nas/freedomnas-core` | Engine, config manager, reconciler → `/usr/lib/freedomnas/core` + `freedomnas` CLI |
| `app-nas/freedomnas-webui` | FastAPI backend and Jinja2 frontend → `/usr/lib/freedomnas/webui` |
| `app-nas/freedomnas-installer` | Provisioning tool → `freedomnas-install` |
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

The ebuilds are **live** (`-9999`) and therefore keyword-masked, as every
live ebuild is. Unmask them in `/etc/portage/package.accept_keywords`:

```
app-nas/* **
```

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

## Live ebuilds

There are no released tags upstream yet, so every ebuild is a `-9999` live
build tracking the **`dev`** branch, where the current work lives. Once `dev`
is merged and tagged:

- drop `EGIT_BRANCH="dev"` from the ebuilds
- add versioned ebuilds using Codeberg's archive tarballs

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
