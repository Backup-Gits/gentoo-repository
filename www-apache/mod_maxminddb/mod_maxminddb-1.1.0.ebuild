# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit apache-module

MY_PN=mod_maxminddb
MY_P=${MY_PN}-${PV}

DESCRIPTION="GeoIP module for apache from maxmind"
HOMEPAGE="https://github.com/maxmind/mod_maxminddb/"
SRC_URI="https://github.com/maxmind/${MY_PN}/releases/download/${PV}/${MY_P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND="dev-libs/apr
	dev-libs/apr-util
	dev-libs/libmaxminddb
	www-servers/apache"

S="${WORKDIR}/${MY_P}"

APACHE2_MOD_FILE=".libs/${MY_PN}.so"
APACHE2_MOD_CONF="80_${PN}"
APACHE2_MOD_DEFINE="MAXMIND"

# Tests require symbols only defined within the Apache binary.
RESTRICT=test

need_apache2

pkg_setup() {
	_init_apache2
	_init_apache2_late
}

src_configure() {
	local myconf=(
		--with-apxs="${APXS}"
	)
	econf ${myconf[@]}
}

src_compile() {
	default
}

src_install() {
	apache-module_src_install
	dodoc Changes.md CONTRIBUTING.md README.md TESTING.md
	dodir /usr/share/MaxMindDB/
}

pkg_postinst() {
	elog "GeoIPLite2 free databases can be downloaded from https://dev.maxmind.com/geoip/geoip2/geolite2/."
	elog "Unpack it and place into /usr/share/MaxMindDB directory"
	elog ""
}
