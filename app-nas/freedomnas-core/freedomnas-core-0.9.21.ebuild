# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )

inherit python-single-r1

DESCRIPTION="FreedomNAS core engine — OS abstraction, config, reconciler"
HOMEPAGE="https://github.com/FreedomNAS/freedomnas-core"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/FreedomNAS/${PN}.git"
	EGIT_BRANCH="dev"
else
	SRC_URI="https://github.com/FreedomNAS/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${PN}-${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="MPL-2.0"
SLOT="0"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="
	${PYTHON_DEPS}
	app-nas/freedomnas-profiles
	$(python_gen_cond_dep '
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/cryptography[${PYTHON_USEDEP}]
	')
	sys-fs/zfs
"

# Upstream ships no setup.py and no [project] table: the modules are laid out
# as a package directory, installed under /usr/lib/freedomnas/core/ and put on
# sys.path with a .pth file. That is the layout ARCHITECTURE.md defines and the
# one the image builder and the installer produce, so distutils-r1 would only
# fight it.
CORE_DIR="/usr/lib/freedomnas/core"

src_prepare() {
	# pytest-only, never part of the installed package
	rm -f conftest.py || die
	default
}

src_install() {
	insinto "${CORE_DIR}/freedomnas"
	doins -r *.py modules

	# freedomnas-core is imported as the `freedomnas` package; the .pth puts
	# its parent on sys.path for the selected interpreter. python_domodule
	# targets site-packages directly, which insinto "$(python_get_sitedir)"
	# cannot do without doubling EPREFIX on a prefix install.
	echo "${EPREFIX}${CORE_DIR}" > "${T}"/freedomnas-core.pth || die
	python_domodule "${T}"/freedomnas-core.pth

	newbin bin/freedomnas freedomnas
	python_fix_shebang "${ED}"/usr/bin/freedomnas

	dodoc README.md
}

pkg_postinst() {
	elog "OS profiles are read from /usr/lib/freedomnas/profiles/"
	elog ""
	elog "Check the engine against this system with:"
	elog "    freedomnas status"
}
