# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit git-r3 python-any-r1

DESCRIPTION="FreedomNAS documentation, for reading offline in the WebUI"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-docs"
EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-docs.git"
EGIT_BRANCH="dev"

LICENSE="MPL-2.0 OFL-1.1"
SLOT="0"
KEYWORDS=""

BDEPEND="
	$(python_gen_any_dep '
		dev-python/mkdocs[${PYTHON_USEDEP}]
		dev-python/mkdocs-material[${PYTHON_USEDEP}]
		dev-python/pymdown-extensions[${PYTHON_USEDEP}]
	')
"

python_check_deps() {
	python_has_version "dev-python/mkdocs[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/mkdocs-material[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/pymdown-extensions[${PYTHON_USEDEP}]"
}

src_compile() {
	local base
	base=$(sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p' debian/changelog) || die
	FREEDOMNAS_DOCS_VERSION="${base%-*}+git.${EGIT_VERSION:0:7}" \
		${EPYTHON} -m mkdocs build --site-dir "${WORKDIR}/site" || die
}

src_install() {
	insinto /usr/lib/freedomnas/docs
	doins -r "${WORKDIR}"/site/.
}
