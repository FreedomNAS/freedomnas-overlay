# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

DESCRIPTION="FreedomNAS documentation, for reading offline in the WebUI"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-docs"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://codeberg.org/FreedomNAS/${PN}.git"
	EGIT_BRANCH="dev"
else
	SRC_URI="https://codeberg.org/FreedomNAS/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${PN}"
	KEYWORDS="~amd64"
fi

LICENSE="MPL-2.0 OFL-1.1"
SLOT="0"

BDEPEND="dev-python/zensical"

src_compile() {
	local version=${PV}
	if [[ ${PV} == 9999 ]]; then
		version=$(sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p' debian/changelog) || die
		version="${version%-*}+git.${EGIT_VERSION:0:7}"
	fi
	FREEDOMNAS_DOCS_VERSION="${version}" zensical build || die
}

src_install() {
	insinto /usr/lib/freedomnas/docs
	doins -r site/.
}
