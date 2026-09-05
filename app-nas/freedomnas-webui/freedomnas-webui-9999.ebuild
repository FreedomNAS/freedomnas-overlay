# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the Mozilla Public License v2.0

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit git-r3 python-single-r1

DESCRIPTION="FreedomNAS WebUI — FastAPI backend and Jinja2 frontend"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-webui"
EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-webui.git"
# Track dev until it is merged into main.
EGIT_BRANCH="dev"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

IUSE="+cron openrc"
# Both would start the WebUI twice.
REQUIRED_USE="${PYTHON_REQUIRED_USE} ?? ( cron openrc )"

RDEPEND="
	${PYTHON_DEPS}
	app-nas/freedomnas-core[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/fastapi[${PYTHON_USEDEP}]
		dev-python/uvicorn[${PYTHON_USEDEP}]
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/python-multipart[${PYTHON_USEDEP}]
		dev-python/python-pam[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/websockets[${PYTHON_USEDEP}]
	')
	cron? ( virtual/cron )
"

WEBUI_DIR="/usr/lib/freedomnas/webui"

src_install() {
	insinto "${WEBUI_DIR}"
	doins -r api frontend websocket

	# firstboot.sh and supervisor.sh are shared verbatim with
	# freedomnas-image-builder and live in freedomnas-profiles/assets/.
	# Symlink rather than vendor a second copy that could drift.
	dodir "${WEBUI_DIR}/bin"
	dosym ../../profiles/assets/firstboot.sh "${WEBUI_DIR}/bin/firstboot.sh"
	dosym ../../profiles/assets/supervisor.sh "${WEBUI_DIR}/bin/supervisor.sh"

	if use cron; then
		insinto /etc/cron.d
		newins "${FILESDIR}"/freedomnas-webui.cron freedomnas-webui
	fi

	if use openrc; then
		newinitd "${FILESDIR}"/freedomnas-webui.initd freedomnas-webui
	fi

}

pkg_postinst() {
	elog "The WebUI listens on port 8080 once started."
	elog ""
	if use cron; then
		elog "It starts at boot through the cron @reboot hook in"
		elog "/etc/cron.d/freedomnas-webui — the init-agnostic path FreedomNAS"
		elog "uses on every edition. Make sure a cron daemon is running."
	elif use openrc; then
		elog "Enable the OpenRC service with:"
		elog "    rc-update add freedomnas-webui default"
	else
		elog "Neither USE=cron nor USE=openrc is set, so nothing starts the"
		elog "WebUI automatically. Start it by hand with:"
		elog "    /usr/lib/freedomnas/webui/bin/firstboot.sh &"
	fi
}
