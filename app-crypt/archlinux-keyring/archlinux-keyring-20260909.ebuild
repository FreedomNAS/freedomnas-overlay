# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

inherit unpacker

DESCRIPTION="Keys that sign Arch Linux packages, for pacman-key --populate archlinux"
HOMEPAGE="https://gitlab.archlinux.org/archlinux/archlinux-keyring"
SRC_URI="https://geo.mirror.pkgbuild.com/core/os/x86_64/${P}-1-any.pkg.tar.zst"
S="${WORKDIR}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="$(unpacker_src_uri_depends)"

src_install() {
	insinto /usr/share/pacman/keyrings
	doins usr/share/pacman/keyrings/*
}
