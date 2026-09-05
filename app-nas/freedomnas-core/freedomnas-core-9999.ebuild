# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the Mozilla Public License v2.0

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )

inherit git-r3 python-single-r1

DESCRIPTION="FreedomNAS core engine — OS abstraction, config, reconciler"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-core"
EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-core.git"
# Track dev until it is merged into main.
EGIT_BRANCH="dev"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

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
