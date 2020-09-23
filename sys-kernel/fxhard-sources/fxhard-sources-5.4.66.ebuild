# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"
ETYPE="sources"
K_WANT_GENPATCHES="base extras experimental"
K_GENPATCHES_VER="67"
inherit kernel-2
detect_version
detect_arch

KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sparc ~x86"
HOMEPAGE="https://dev.gentoo.org/~mpagano/genpatches"
IUSE="experimental"


DESCRIPTION="Full sources including the Gentoo patchset for the ${KV_MAJOR}.${KV_MINOR} kernel tree"
SRC_URI="${KERNEL_URI} ${GENPATCHES_URI} ${ARCH_URI}"
P_EXCLUDE="2400_wireguard-backport-v5.4.53.patch"

src_prepare() {
#	eapply -p1 "${FILESDIR}/linux-5.4.58.patch"
	#https://github.com/anthraxx/linux-hardened
	eapply -p1 "${FILESDIR}/linux-hardened-${KV_MAJOR}.${KV_MINOR}.65.a.patch"
	#https://github.com/anthraxx/linux-hardened/pull/41
	eapply -p1 "${FILESDIR}/001-deny-access-to-overly-permissive-IPC-objects.patch"
	eapply -p1 "${FILESDIR}/002-deny-access-to-overly-permissive-IPC-objects.patch"
	#https://github.com/anthraxx/linux-hardened/pull/35
	eapply -p1 "${FILESDIR}/003-add-runtime-read-only-mount-protection.patch"
	#https://github.com/anthraxx/linux-hardened/pull/40
	eapply -p1 "${FILESDIR}/004-make-more-sysctl-constants-read-only.patch"
	eapply_user
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "For more info on this patchset, and how to report problems, see:"
	einfo "${HOMEPAGE}"
}

pkg_postrm() {
	kernel-2_pkg_postrm
}
