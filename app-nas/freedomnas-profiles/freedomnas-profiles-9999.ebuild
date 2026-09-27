# Copyright 2026 FreedomNAS Team
# Distributed under the terms of the GNU General Public License v2 or later

EAPI=8

inherit git-r3

DESCRIPTION="FreedomNAS OS profiles — the JSON translator layer"
HOMEPAGE="https://codeberg.org/FreedomNAS/freedomnas-profiles"
EGIT_REPO_URI="https://codeberg.org/FreedomNAS/freedomnas-profiles.git"
# Track dev until it is merged into main.
EGIT_BRANCH="dev"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

# Pure data: JSON command maps plus the boot-chain assets shared with
# freedomnas-image-builder. Nothing here is compiled or executed at build time,
# and nothing is needed at runtime beyond the files themselves.

src_install() {
	insinto /usr/lib/freedomnas/profiles
	doins -r os init storage network shares users installer packages assets

	# doins drops the executable bit; these three are run, not read.
	fperms 0755 /usr/lib/freedomnas/profiles/assets/zz-dracut-uki
	fperms 0755 /usr/lib/freedomnas/profiles/assets/firstboot.sh
	fperms 0755 /usr/lib/freedomnas/profiles/assets/supervisor.sh

	dodoc README.md CONTRIBUTING.md
}
