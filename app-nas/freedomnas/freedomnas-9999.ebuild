# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

DESCRIPTION="FreedomNAS — OS-agnostic storage appliance (meta package)"
HOMEPAGE="https://codeberg.org/FreedomNAS"
S="${WORKDIR}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS=""

IUSE="+webui installer"

RDEPEND="
	app-nas/freedomnas-core
	app-nas/freedomnas-profiles
	webui? ( app-nas/freedomnas-webui )
	installer? ( app-nas/freedomnas-installer )
"
