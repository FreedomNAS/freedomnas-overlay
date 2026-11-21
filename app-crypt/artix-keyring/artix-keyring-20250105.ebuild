# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

inherit unpacker

DESCRIPTION="Keys that sign Artix Linux packages, for pacman-key --populate artix"
HOMEPAGE="https://gitea.artixlinux.org/artix/artix-keyring"
SRC_URI="
	https://mirror1.artixlinux.org/repos/system/os/x86_64/${P}-1-any.pkg.tar.zst
	https://mirrors.dotsrc.org/artix-linux/repos/system/os/x86_64/${P}-1-any.pkg.tar.zst
	https://mirror.clarkson.edu/artix-linux/repos/system/os/x86_64/${P}-1-any.pkg.tar.zst
"
S="${WORKDIR}"

LICENSE="GPL-1+"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="$(unpacker_src_uri_depends)"

src_install() {
	insinto /usr/share/pacman/keyrings
	doins usr/share/pacman/keyrings/*
}
