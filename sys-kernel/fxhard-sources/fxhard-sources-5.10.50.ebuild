# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"
ETYPE="sources"
K_WANT_GENPATCHES="base extras experimental"
K_GENPATCHES_VER="56"
K_NODRYRUN="1"
K_NOSETEXTRAVERSION="true"

inherit kernel-2
detect_version
detect_arch

KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sparc ~x86"
HOMEPAGE="https://dev.gentoo.org/~mpagano/genpatches"
IUSE="experimental"

DESCRIPTION="Full sources including the Gentoo patchset for the ${KV_MAJOR}.${KV_MINOR} kernel tree"
LINUX_HARDENED_URI="https://github.com/anthraxx/linux-hardened/releases/download/${KV_MAJOR}.${KV_MINOR}.${KV_PATCH}-hardened1/linux-hardened-${KV_MAJOR}.${KV_MINOR}.${KV_PATCH}-hardened1.patch"
SRC_URI="${KERNEL_URI} ${GENPATCHES_URI} ${ARCH_URI} ${LINUX_HARDENED_URI}"

UNIPATCH_EXCLUDE="1510_fs-enable-link-security-restrictions-by-default.patch 4567_distro-Gentoo-Kconfig.patch"

PATCHES=(
	"${DISTDIR}/linux-hardened-${KV_MAJOR}.${KV_MINOR}.${KV_PATCH}-hardened1.patch"
	"${FILESDIR}/${KV_MAJOR}.${KV_MINOR}-deny-access-to-overly-permissive-IPC-objects.patch"
	"${FILESDIR}/${KV_MAJOR}.${KV_MINOR}-make-more-sysctl-constants-read-only.patch.patch"
	"${FILESDIR}/${KV_MAJOR}.${KV_MINOR}-sysfs-restrict.patch"
	"${FILESDIR}/${KV_MAJOR}.${KV_MINOR}-modharden.patch"
	"${FILESDIR}/NOWRITEEXEC-and-PAX-features-MPROTECT-EMUTRAMP-RANDKSTACK-RAP-and-bpf-ext4-bonding-fix-compilation-errors.patch"
	"${FILESDIR}/need-cap_sys_admin-for-sysrq.patch"
	"${FILESDIR}/4567_distro-Gentoo-Kconfig-fxmod.patch"
)

src_prepare() {
	default
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "For more info on this patchset, and how to report problems, see:"
	einfo "${HOMEPAGE}"
}

pkg_postrm() {
	kernel-2_pkg_postrm
}
