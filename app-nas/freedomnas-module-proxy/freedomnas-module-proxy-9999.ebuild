# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

DESCRIPTION="FreedomNAS reverse proxy: Caddy with HTTPS for every web app"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-proxy"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-proxy.git"
	EGIT_BRANCH="dev"
else
	SRC_URI="https://codeberg.org/FreedomNAS/freedomnas-proxy/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/freedomnas-proxy"
	KEYWORDS="~amd64"
fi

LICENSE="MPL-2.0"
SLOT="0"

# A community module: freedomnas-core loads it from /usr/lib/freedomnas/modules
# and merges its profile fragment from /usr/lib/freedomnas/profiles.
# Caddy is installed from the WebUI (www-servers/caddy, its own profile).
# 0.9.12's core loaded a single modules directory, so a community module
# beside it would hide the core's own.
RDEPEND="
	>=app-nas/freedomnas-core-0.9.13
	>=app-nas/freedomnas-webui-0.9.13
"

src_install() {
	insinto /usr/lib/freedomnas/modules
	doins -r modules/proxy
	insinto /usr/lib/freedomnas/profiles
	doins -r profiles/proxy
	dodoc README.md
}
