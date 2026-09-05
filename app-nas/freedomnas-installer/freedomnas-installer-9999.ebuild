# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the Mozilla Public License v2.0

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )

inherit git-r3 python-single-r1

DESCRIPTION="Profile-driven FreedomNAS installer (clean install or in-place)"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-installer"
EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-installer.git"
# Track dev until it is merged into main.
EGIT_BRANCH="dev"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# The installer resolves every OS command through the engine, so core and
# profiles are hard requirements, not conveniences. The rest is the host-side
# tooling the partitioning and bootstrap sections of the profiles name.
RDEPEND="
	${PYTHON_DEPS}
	app-nas/freedomnas-core[${PYTHON_SINGLE_USEDEP}]
	app-nas/freedomnas-profiles
	dev-util/dialog
	net-misc/curl
	sys-apps/gptfdisk
	sys-block/parted
	sys-boot/efibootmgr
	sys-fs/dosfstools
	sys-fs/zfs
	sys-kernel/dracut
"

INSTALLER_DIR="/usr/lib/freedomnas/installer"

src_install() {
	insinto "${INSTALLER_DIR}"
	doins setup.py
	fperms 0755 "${INSTALLER_DIR}"/setup.py

	insinto "${INSTALLER_DIR}/lib"
	doins lib/*.py

	dosym "${INSTALLER_DIR}"/setup.py /usr/bin/freedomnas-install

	dodoc README.md
}

pkg_postinst() {
	elog "Run the installer with:"
	elog "    freedomnas-install"
	elog ""
	elog "It can install a chosen edition onto a dedicated disk, or install"
	elog "FreedomNAS onto this running system (--mode inplace). See what a"
	elog "run would do, without touching anything and without root:"
	elog "    freedomnas-install --dry-run"
	elog ""
	elog "Bootstrapping needs the target OS's own tooling, so a Gentoo host"
	elog "installs the Linux editions (Gentoo, Debian, Arch, Artix, Void);"
	elog "FreeBSD needs a FreeBSD installer environment."
}
