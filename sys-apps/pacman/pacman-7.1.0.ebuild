# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

inherit meson

DESCRIPTION="Arch Linux package manager, to bootstrap Arch and Artix from a Gentoo host"
HOMEPAGE="https://pacman.archlinux.page/ https://gitlab.archlinux.org/pacman/pacman"
SRC_URI="https://gitlab.archlinux.org/-/project/19637/uploads/f7f47e176b9ad29a31a0704e5df8fc38/${P}.tar.xz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="nls"

DEPEND="
	app-arch/libarchive:=
	app-crypt/gpgme:1=
	dev-libs/openssl:=
	net-misc/curl
"
RDEPEND="
	${DEPEND}
	app-alternatives/awk
	app-crypt/gnupg
	app-shells/bash
	sys-apps/coreutils
	sys-apps/grep
"
BDEPEND="
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
"

src_configure() {
	# Scriptlets and ldconfig run inside the Arch or Artix root being
	# installed, so these are that system's paths, not the host's.
	local emesonargs=(
		--localstatedir="${EPREFIX}"/var
		-Dcrypto=openssl
		-Dcurl=enabled
		-Ddoc=disabled
		-Ddoxygen=disabled
		-Dfile-seccomp=disabled
		-Dgpgme=enabled
		-Dldconfig=/usr/bin/ldconfig
		-Dscriptlet-shell=/usr/bin/bash
		$(meson_use nls i18n)
	)
	meson_src_configure
}

src_install() {
	meson_src_install
	rm -r "${ED}"/var || die
}
