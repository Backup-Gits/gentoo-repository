# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
PHP_EXT_NAME="snuffleupagus"
PHP_EXT_INI="yes"
PHP_EXT_ZENDEXT="no"

USE_PHP="php7-2 php7-4 php8-0"

inherit php-ext-pecl-r3

DESCRIPTION="snuffleupagus is an advanced protection system for PHP installations"
HOMEPAGE="https://snuffleupagus.readthedocs.io"
SRC_URI="https://github.com/jvoisin/snuffleupagus/archive/refs/tags/v${PV}.tar.gz"
LICENSE="GPL-COMPATIBLE"
SLOT="0"
IUSE=""

PHP_EXT_S="${WORKDIR}/${P}/src"

src_configure() {
	local PHP_EXT_ECONF_ARGS=(
		--enable-snuffleupagus
		--with-pic
	)
	php-ext-source-r3_src_configure
}

src_install() {
	php-ext-source-r3_src_install
	php-ext-source-r3_addtoinifiles "sp.configuration_file" "/etc/php/conf.d/default.rules"
	php-ext-source-r3_addtoinifiles ";sp.configuration_file" "/etc/php/conf.d/typo3.rules"
	php-ext-source-r3_addtoinifiles ";sp.configuration_file" "/etc/php/conf.d/rips.rules"

	local dirs=(
			/etc/php/snuffleupagus
	)

	for dir in "${dirs[@]}"; do
		dodir "${dir}"
		keepdir "${dir}"
	done

	insinto /etc/php/snuffleupagus
	doins ${S}/config/default.rules
	doins ${S}/config/rips.rules
	doins ${S}/config/typo3.rules
}
