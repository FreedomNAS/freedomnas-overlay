# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Upgrade all the things — upstream's statically linked binary"
HOMEPAGE="https://github.com/topgrade-rs/topgrade"
SRC_URI="https://github.com/topgrade-rs/topgrade/releases/download/v${PV}/topgrade-v${PV}-x86_64-unknown-linux-musl.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="-* amd64"

RDEPEND="!app-admin/topgrade"

# musl, statically linked: nothing to link against and nothing to strip.
QA_PREBUILT="usr/bin/topgrade"
RESTRICT="strip"

src_install() {
	dobin topgrade
}
