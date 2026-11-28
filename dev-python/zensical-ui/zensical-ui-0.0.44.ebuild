# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

DISTUTILS_USE_PEP517=hatchling
PYTHON_COMPAT=( python3_{11..15} )

inherit distutils-r1 pypi

DESCRIPTION="Templates and browser assets for Zensical"
HOMEPAGE="
	https://zensical.org/
	https://github.com/zensical/ui/
	https://pypi.org/project/zensical-ui/
"

LICENSE="MIT"
# Bundled icon sets: Font Awesome, Lucide, Material (Pictogrammers), Octicons, Simple Icons
LICENSE+=" Apache-2.0 CC-BY-4.0 OFL-1.1 ISC CC0-1.0"
SLOT="0"
KEYWORDS="~amd64"
