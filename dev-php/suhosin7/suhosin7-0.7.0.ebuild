# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

PHP_EXT_NAME="suhosin7"
PHP_EXT_INI="no"
PHP_EXT_ZENDEXT="no"
USE_PHP="php7-2"

inherit php-ext-source-r3

DESCRIPTION="Suhosin is an advanced protection system for PHP installations"
HOMEPAGE="https://www.suhosin.org/"
SRC_URI="https://ca95eb596e48788b5275bacf9167e788.zeroone.sk/distfiles/suhosin7-0.7.0.tar.gz"
LICENSE="PHP-3.01"
SLOT="0"
IUSE=""

for target in ${USE_PHP}; do
	slot=${target/php}
	slot=${slot/-/.}
	PHPUSEDEPEND="${PHPUSEDEPEND}
	php_targets_${target}? ( dev-lang/php:${slot}[unicode] )"
done

DEPEND="${PHPUSEDEPEND}"
RDEPEND="${DEPEND}"

DOCS=( CREDITS )

src_configure() {
	local PHP_EXT_ECONF_ARGS=(
		--enable-suhosin7
		--enable-suhosin7-experimental
		--with-pic
	)
	php-ext-source-r3_src_configure
}
src_install() {
	php-ext-source-r3_src_install

	local slot inifile
	for slot in $(php_get_slots); do
		php_init_slot_env ${slot}
		for inifile in $(php_slot_ini_files "${slot}") ; do
			insinto "${inifile/${PHP_EXT_NAME}.ini/}"
			insopts -m644
			doins "suhosin7.ini"
		done
	done
}

src_test() {
	# Makefile passes a hard-coded -d extension_dir=./modules, we move the lib
	# away from there in src_compile
	for slot in `php_get_slots`; do
		php_init_slot_env ${slot}
		NO_INTERACTION="yes" emake test || die "emake test failed for slot ${slot}"
	done
}
