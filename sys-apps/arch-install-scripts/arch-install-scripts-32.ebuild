# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

inherit shell-completion

DESCRIPTION="pacstrap and genfstab, to install Arch or Artix from any host"
HOMEPAGE="https://gitlab.archlinux.org/archlinux/arch-install-scripts"
SRC_URI="https://gitlab.archlinux.org/archlinux/arch-install-scripts/-/archive/v${PV}/arch-install-scripts-v${PV}.tar.bz2"
S="${WORKDIR}/arch-install-scripts-v${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

# arch-chroot comes from ::gentoo's sys-apps/arch-chroot, built from the
# same tarball; installing it here as well would collide with it.
RDEPEND="
	app-alternatives/awk
	app-shells/bash
	sys-apps/coreutils
	sys-apps/grep
	sys-apps/pacman
	sys-apps/util-linux
"
BDEPEND="app-text/asciidoc"

src_compile() {
	emake MANS="doc/genfstab.8 doc/pacstrap.8" BINPROGS="genfstab pacstrap"
}

src_test() {
	emake MANS="doc/genfstab.8 doc/pacstrap.8" BINPROGS="genfstab pacstrap" check
}

src_install() {
	dobin genfstab pacstrap
	doman doc/genfstab.8 doc/pacstrap.8
	dobashcomp completion/bash/genfstab completion/bash/pacstrap
	dozshcomp completion/zsh/_genfstab completion/zsh/_pacstrap
}
