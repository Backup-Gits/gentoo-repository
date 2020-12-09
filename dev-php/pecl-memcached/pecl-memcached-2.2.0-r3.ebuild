# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PHP_EXT_NAME="memcached"
DOCS=( ChangeLog README.markdown )

USE_PHP="php5-6"
inherit php-ext-pecl-r3

DESCRIPTION="Interface PHP with memcached via libmemcached library"
LICENSE="PHP-3"
SLOT="5.6"
KEYWORDS="amd64 x86"
IUSE="examples igbinary json sasl +session test"

COMMON_DEPEND=">=dev-libs/libmemcached-1.0.14[sasl?]
	sys-libs/zlib
"

RDEPEND="
		${COMMON_DEPEND} dev-lang/php:5.6[session?,json?]
		igbinary? ( dev-php/igbinary[php_targets_php5-6(-)] )
	"
DEPEND="${RDEPEND} test? ( net-misc/memcached )"

src_prepare(){
	php-ext-source-r3_src_prepare
}

src_configure() {
	local PHP_EXT_ECONF_ARGS="--enable-memcached
		$(use_enable session memcached-session)
		$(use_enable sasl memcached-sasl)
		$(use_enable json memcached-json)
		$(use_enable igbinary memcached-igbinary)"

	php-ext-source-r3_src_configure
}

src_test() {
	local memcached_opts=( -d -P "${T}/memcached.pid" -p 11211 -l 127.0.0.1 )
	[[ ${EUID} == 0 ]] && memcached_opts+=( -u portage )
	memcached "${memcached_opts[@]}" || die "Can't start memcached test server"

	local exit_status
	php-ext-source-r3_src_test
	exit_status=$?

	kill "$(<"${T}/memcached.pid")"
	return ${exit_status}
}

src_install(){
	php-ext-source-r3_src_install
}
