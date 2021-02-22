# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

inherit apache-module eutils

MY_PN=mod_ruid2
MY_P=${MY_PN}-${PV}

DESCRIPTION="mod_ruid2 module for apache webserver"
HOMEPAGE="https://github.com/mind04/mod-ruid2"
SRC_URI="https://github.com/mind04/mod-ruid2/archive/mod_ruid2-${PV}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND="dev-libs/apr
	dev-libs/apr-util
	www-servers/apache"

S="${WORKDIR}/mod-ruid2-${MY_P}"

APACHE2_MOD_CONF="99_${PN}"
APACHE2_MOD_DEFINE="RUID2"
APACHE2_MOD_FILE="${S}/.libs/${MY_PN}.so"
APXS2_ARGS="-l cap -c ${MY_PN}.c"

need_apache2

pkg_setup() {
	_init_apache2
	_init_apache2_late
}

src_prepare() {
	eapply "${FILESDIR}"/Make-sure-ap_hook_post_read_request-always-runs-first.patch
	eapply_user
}

src_install() {
	apache-module_src_install
	dodoc LICENSE README
}
