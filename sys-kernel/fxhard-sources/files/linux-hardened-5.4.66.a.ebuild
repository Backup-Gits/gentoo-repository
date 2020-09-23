diff --git a/Documentation/admin-guide/kernel-parameters.txt b/Documentation/admin-guide/kernel-parameters.txt
index 13984b6cc322..2bc8ea56ca41 100644
--- a/Documentation/admin-guide/kernel-parameters.txt
+++ b/Documentation/admin-guide/kernel-parameters.txt
@@ -509,16 +509,6 @@
 			nosocket -- Disable socket memory accounting.
 			nokmem -- Disable kernel memory accounting.
 
-	checkreqprot	[SELINUX] Set initial checkreqprot flag value.
-			Format: { "0" | "1" }
-			See security/selinux/Kconfig help text.
-			0 -- check protection applied by kernel (includes
-				any implied execute protection).
-			1 -- check protection requested by application.
-			Default value is set via a kernel config option.
-			Value can be changed at runtime via
-				/selinux/checkreqprot.
-
 	cio_ignore=	[S390]
 			See Documentation/s390/common_io.rst for details.
 	clk_ignore_unused
@@ -3349,6 +3339,11 @@
 			the specified number of seconds.  This is to be used if
 			your oopses keep scrolling off the screen.
 
+	extra_latent_entropy
+			Enable a very simple form of latent entropy extraction
+			from the first 4GB of memory as the bootmem allocator
+			passes the memory pages to the buddy allocator.
+
 	pcbit=		[HW,ISDN]
 
 	pcd.		[PARIDE]
diff --git a/Documentation/admin-guide/sysctl/kernel.rst b/Documentation/admin-guide/sysctl/kernel.rst
index 032c7cd3cede..cc3491b05976 100644
--- a/Documentation/admin-guide/sysctl/kernel.rst
+++ b/Documentation/admin-guide/sysctl/kernel.rst
@@ -102,6 +102,7 @@ show up in /proc/sys/kernel:
 - sysctl_writes_strict
 - tainted                     ==> Documentation/admin-guide/tainted-kernels.rst
 - threads-max
+- tiocsti_restrict
 - unknown_nmi_panic
 - watchdog
 - watchdog_thresh
@@ -1114,6 +1115,25 @@ thread structures would occupy too much (more than 1/8th) of the
 available RAM pages threads-max is reduced accordingly.
 
 
+tiocsti_restrict:
+=================
+
+This toggle indicates whether unprivileged users are prevented from using the
+TIOCSTI ioctl to inject commands into other processes which share a tty
+session.
+
+When tiocsti_restrict is set to (0) there are no restrictions(accept the
+default restriction of only being able to injection commands into one's own
+tty). When tiocsti_restrict is set to (1), users must have CAP_SYS_ADMIN to
+use the TIOCSTI ioctl.
+
+When user namespaces are in use, the check for the capability CAP_SYS_ADMIN is
+done against the user namespace that originally opened the tty.
+
+The kernel config option CONFIG_SECURITY_TIOCSTI_RESTRICT sets the default
+value of tiocsti_restrict.
+
+
 unknown_nmi_panic:
 ==================
 
diff --git a/Documentation/networking/ip-sysctl.txt b/Documentation/networking/ip-sysctl.txt
index 8d4ad1d1ae26..e8f9a244f974 100644
--- a/Documentation/networking/ip-sysctl.txt
+++ b/Documentation/networking/ip-sysctl.txt
@@ -583,6 +583,23 @@ tcp_comp_sack_nr - INTEGER
 
 	Default : 44
 
+tcp_simult_connect - BOOLEAN
+	Enable TCP simultaneous connect that adds a weakness in Linux's strict
+	implementation of TCP that allows two clients to connect to each other
+	without either entering a listening state. The weakness allows an attacker
+	to easily prevent a client from connecting to a known server provided the
+	source port for the connection is guessed correctly.
+
+	As the weakness could be used to prevent an antivirus or IPS from fetching
+	updates, or prevent an SSL gateway from fetching a CRL, it should be
+	eliminated by disabling this option. Though Linux is one of few operating
+	systems supporting simultaneous connect, it has no legitimate use in
+	practice and is rarely supported by firewalls.
+
+	Disabling this may break TCP STUNT which is used by some applications for
+	NAT traversal.
+	Default: Value of CONFIG_TCP_SIMULT_CONNECT_DEFAULT_ON
+
 tcp_slow_start_after_idle - BOOLEAN
 	If set, provide RFC2861 behavior and time out the congestion
 	window after an idle period.  An idle period is defined at
diff --git a/arch/Kconfig b/arch/Kconfig
index 238dccfa7691..85926f13fe40 100644
--- a/arch/Kconfig
+++ b/arch/Kconfig
@@ -653,7 +653,7 @@ config ARCH_MMAP_RND_BITS
 	int "Number of bits to use for ASLR of mmap base address" if EXPERT
 	range ARCH_MMAP_RND_BITS_MIN ARCH_MMAP_RND_BITS_MAX
 	default ARCH_MMAP_RND_BITS_DEFAULT if ARCH_MMAP_RND_BITS_DEFAULT
-	default ARCH_MMAP_RND_BITS_MIN
+	default ARCH_MMAP_RND_BITS_MAX
 	depends on HAVE_ARCH_MMAP_RND_BITS
 	help
 	  This value can be used to select the number of bits to use to
@@ -687,7 +687,7 @@ config ARCH_MMAP_RND_COMPAT_BITS
 	int "Number of bits to use for ASLR of mmap base address for compatible applications" if EXPERT
 	range ARCH_MMAP_RND_COMPAT_BITS_MIN ARCH_MMAP_RND_COMPAT_BITS_MAX
 	default ARCH_MMAP_RND_COMPAT_BITS_DEFAULT if ARCH_MMAP_RND_COMPAT_BITS_DEFAULT
-	default ARCH_MMAP_RND_COMPAT_BITS_MIN
+	default ARCH_MMAP_RND_COMPAT_BITS_MAX
 	depends on HAVE_ARCH_MMAP_RND_COMPAT_BITS
 	help
 	  This value can be used to select the number of bits to use to
@@ -906,6 +906,7 @@ config ARCH_HAS_REFCOUNT
 
 config REFCOUNT_FULL
 	bool "Perform full reference count validation at the expense of speed"
+	default y
 	help
 	  Enabling this switches the refcounting infrastructure from a fast
 	  unchecked atomic_t implementation to a fully state checked
diff --git a/arch/arm64/Kconfig b/arch/arm64/Kconfig
index a0bc9bbb92f3..94eec74e4949 100644
--- a/arch/arm64/Kconfig
+++ b/arch/arm64/Kconfig
@@ -1155,6 +1155,7 @@ config RODATA_FULL_DEFAULT_ENABLED
 
 config ARM64_SW_TTBR0_PAN
 	bool "Emulate Privileged Access Never using TTBR0_EL1 switching"
+	default y
 	help
 	  Enabling this option prevents the kernel from accessing
 	  user-space memory directly by pointing TTBR0_EL1 to a reserved
@@ -1554,6 +1555,7 @@ config RANDOMIZE_BASE
 	bool "Randomize the address of the kernel image"
 	select ARM64_MODULE_PLTS if MODULES
 	select RELOCATABLE
+	default y
 	help
 	  Randomizes the virtual address at which the kernel image is
 	  loaded, as a security feature that deters exploit attempts
diff --git a/arch/arm64/Kconfig.debug b/arch/arm64/Kconfig.debug
index cf09010d825f..dc4083ceff57 100644
--- a/arch/arm64/Kconfig.debug
+++ b/arch/arm64/Kconfig.debug
@@ -43,6 +43,7 @@ config ARM64_RANDOMIZE_TEXT_OFFSET
 config DEBUG_WX
 	bool "Warn on W+X mappings at boot"
 	select ARM64_PTDUMP_CORE
+	default y
 	---help---
 	  Generate a warning if any W+X mappings are found at boot.
 
diff --git a/arch/arm64/configs/defconfig b/arch/arm64/configs/defconfig
index c9a867ac32d4..5c4d264f6a6e 100644
--- a/arch/arm64/configs/defconfig
+++ b/arch/arm64/configs/defconfig
@@ -1,4 +1,3 @@
-CONFIG_SYSVIPC=y
 CONFIG_POSIX_MQUEUE=y
 CONFIG_AUDIT=y
 CONFIG_NO_HZ_IDLE=y
diff --git a/arch/arm64/include/asm/elf.h b/arch/arm64/include/asm/elf.h
index b618017205a3..0a228dbcad65 100644
--- a/arch/arm64/include/asm/elf.h
+++ b/arch/arm64/include/asm/elf.h
@@ -103,14 +103,10 @@
 
 /*
  * This is the base location for PIE (ET_DYN with INTERP) loads. On
- * 64-bit, this is above 4GB to leave the entire 32-bit address
+ * 64-bit, this is raised to 4GB to leave the entire 32-bit address
  * space open for things that want to use the area for 32-bit pointers.
  */
-#ifdef CONFIG_ARM64_FORCE_52BIT
-#define ELF_ET_DYN_BASE		(2 * TASK_SIZE_64 / 3)
-#else
-#define ELF_ET_DYN_BASE		(2 * DEFAULT_MAP_WINDOW_64 / 3)
-#endif /* CONFIG_ARM64_FORCE_52BIT */
+#define ELF_ET_DYN_BASE		0x100000000UL
 
 #ifndef __ASSEMBLY__
 
@@ -164,10 +160,10 @@ extern int arch_setup_additional_pages(struct linux_binprm *bprm,
 /* 1GB of VA */
 #ifdef CONFIG_COMPAT
 #define STACK_RND_MASK			(test_thread_flag(TIF_32BIT) ? \
-						0x7ff >> (PAGE_SHIFT - 12) : \
-						0x3ffff >> (PAGE_SHIFT - 12))
+						((1UL << mmap_rnd_compat_bits) - 1) >> (PAGE_SHIFT - 12) : \
+						((1UL << mmap_rnd_bits) - 1) >> (PAGE_SHIFT - 12))
 #else
-#define STACK_RND_MASK			(0x3ffff >> (PAGE_SHIFT - 12))
+#define STACK_RND_MASK			(((1UL << mmap_rnd_bits) - 1) >> (PAGE_SHIFT - 12))
 #endif
 
 #ifdef __AARCH64EB__
diff --git a/arch/x86/Kconfig b/arch/x86/Kconfig
index 8ef85139553f..e16076b30625 100644
--- a/arch/x86/Kconfig
+++ b/arch/x86/Kconfig
@@ -1219,8 +1219,7 @@ config VM86
        default X86_LEGACY_VM86
 
 config X86_16BIT
-	bool "Enable support for 16-bit segments" if EXPERT
-	default y
+	bool "Enable support for 16-bit segments"
 	depends on MODIFY_LDT_SYSCALL
 	---help---
 	  This option is required by programs like Wine to run 16-bit
@@ -2365,7 +2364,7 @@ config COMPAT_VDSO
 choice
 	prompt "vsyscall table for legacy applications"
 	depends on X86_64
-	default LEGACY_VSYSCALL_XONLY
+	default LEGACY_VSYSCALL_NONE
 	help
 	  Legacy user code that does not know how to find the vDSO expects
 	  to be able to issue three syscalls by calling fixed addresses in
@@ -2461,8 +2460,7 @@ config CMDLINE_OVERRIDE
 	  be set to 'N' under normal conditions.
 
 config MODIFY_LDT_SYSCALL
-	bool "Enable the LDT (local descriptor table)" if EXPERT
-	default y
+	bool "Enable the LDT (local descriptor table)"
 	---help---
 	  Linux can allow user programs to install a per-process x86
 	  Local Descriptor Table (LDT) using the modify_ldt(2) system
diff --git a/arch/x86/Kconfig.debug b/arch/x86/Kconfig.debug
index bf9cd83de777..13ef90f3de52 100644
--- a/arch/x86/Kconfig.debug
+++ b/arch/x86/Kconfig.debug
@@ -91,6 +91,7 @@ config EFI_PGT_DUMP
 config DEBUG_WX
 	bool "Warn on W+X mappings at boot"
 	select X86_PTDUMP_CORE
+	default y
 	---help---
 	  Generate a warning if any W+X mappings are found at boot.
 
diff --git a/arch/x86/configs/x86_64_defconfig b/arch/x86/configs/x86_64_defconfig
index 3087c5e351e7..a8fc26b4031b 100644
--- a/arch/x86/configs/x86_64_defconfig
+++ b/arch/x86/configs/x86_64_defconfig
@@ -1,5 +1,4 @@
 # CONFIG_LOCALVERSION_AUTO is not set
-CONFIG_SYSVIPC=y
 CONFIG_POSIX_MQUEUE=y
 CONFIG_BSD_PROCESS_ACCT=y
 CONFIG_TASKSTATS=y
diff --git a/arch/x86/entry/vdso/vma.c b/arch/x86/entry/vdso/vma.c
index f5937742b290..6655ce228e25 100644
--- a/arch/x86/entry/vdso/vma.c
+++ b/arch/x86/entry/vdso/vma.c
@@ -198,55 +198,9 @@ static int map_vdso(const struct vdso_image *image, unsigned long addr)
 }
 
 #ifdef CONFIG_X86_64
-/*
- * Put the vdso above the (randomized) stack with another randomized
- * offset.  This way there is no hole in the middle of address space.
- * To save memory make sure it is still in the same PTE as the stack
- * top.  This doesn't give that many random bits.
- *
- * Note that this algorithm is imperfect: the distribution of the vdso
- * start address within a PMD is biased toward the end.
- *
- * Only used for the 64-bit and x32 vdsos.
- */
-static unsigned long vdso_addr(unsigned long start, unsigned len)
-{
-	unsigned long addr, end;
-	unsigned offset;
-
-	/*
-	 * Round up the start address.  It can start out unaligned as a result
-	 * of stack start randomization.
-	 */
-	start = PAGE_ALIGN(start);
-
-	/* Round the lowest possible end address up to a PMD boundary. */
-	end = (start + len + PMD_SIZE - 1) & PMD_MASK;
-	if (end >= TASK_SIZE_MAX)
-		end = TASK_SIZE_MAX;
-	end -= len;
-
-	if (end > start) {
-		offset = get_random_int() % (((end - start) >> PAGE_SHIFT) + 1);
-		addr = start + (offset << PAGE_SHIFT);
-	} else {
-		addr = start;
-	}
-
-	/*
-	 * Forcibly align the final address in case we have a hardware
-	 * issue that requires alignment for performance reasons.
-	 */
-	addr = align_vdso_addr(addr);
-
-	return addr;
-}
-
 static int map_vdso_randomized(const struct vdso_image *image)
 {
-	unsigned long addr = vdso_addr(current->mm->start_stack, image->size-image->sym_vvar_start);
-
-	return map_vdso(image, addr);
+	return map_vdso(image, 0);
 }
 #endif
 
diff --git a/arch/x86/include/asm/elf.h b/arch/x86/include/asm/elf.h
index 69c0f892e310..f9f7a85bb71e 100644
--- a/arch/x86/include/asm/elf.h
+++ b/arch/x86/include/asm/elf.h
@@ -248,11 +248,11 @@ extern int force_personality32;
 
 /*
  * This is the base location for PIE (ET_DYN with INTERP) loads. On
- * 64-bit, this is above 4GB to leave the entire 32-bit address
+ * 64-bit, this is raised to 4GB to leave the entire 32-bit address
  * space open for things that want to use the area for 32-bit pointers.
  */
 #define ELF_ET_DYN_BASE		(mmap_is_ia32() ? 0x000400000UL : \
-						  (DEFAULT_MAP_WINDOW / 3 * 2))
+						  0x100000000UL)
 
 /* This yields a mask that user programs can use to figure out what
    instruction set this CPU supports.  This could be done in user space,
@@ -312,8 +312,8 @@ extern bool mmap_address_hint_valid(unsigned long addr, unsigned long len);
 
 #ifdef CONFIG_X86_32
 
-#define __STACK_RND_MASK(is32bit) (0x7ff)
-#define STACK_RND_MASK (0x7ff)
+#define __STACK_RND_MASK(is32bit) ((1UL << mmap_rnd_bits) - 1)
+#define STACK_RND_MASK ((1UL << mmap_rnd_bits) - 1)
 
 #define ARCH_DLINFO		ARCH_DLINFO_IA32
 
@@ -322,7 +322,11 @@ extern bool mmap_address_hint_valid(unsigned long addr, unsigned long len);
 #else /* CONFIG_X86_32 */
 
 /* 1GB for 64bit, 8MB for 32bit */
-#define __STACK_RND_MASK(is32bit) ((is32bit) ? 0x7ff : 0x3fffff)
+#ifdef CONFIG_COMPAT
+#define __STACK_RND_MASK(is32bit) ((is32bit) ? (1UL << mmap_rnd_compat_bits) - 1 : (1UL << mmap_rnd_bits) - 1)
+#else
+#define __STACK_RND_MASK(is32bit) ((1UL << mmap_rnd_bits) - 1)
+#endif
 #define STACK_RND_MASK __STACK_RND_MASK(mmap_is_ia32())
 
 #define ARCH_DLINFO							\
@@ -380,5 +384,4 @@ struct va_alignment {
 } ____cacheline_aligned;
 
 extern struct va_alignment va_align;
-extern unsigned long align_vdso_addr(unsigned long);
 #endif /* _ASM_X86_ELF_H */
diff --git a/arch/x86/include/asm/tlbflush.h b/arch/x86/include/asm/tlbflush.h
index 6f66d841262d..b786e7cb395d 100644
--- a/arch/x86/include/asm/tlbflush.h
+++ b/arch/x86/include/asm/tlbflush.h
@@ -295,6 +295,7 @@ static inline void cr4_set_bits_irqsoff(unsigned long mask)
 	unsigned long cr4;
 
 	cr4 = this_cpu_read(cpu_tlbstate.cr4);
+	BUG_ON(cr4 != __read_cr4());
 	if ((cr4 | mask) != cr4)
 		__cr4_set(cr4 | mask);
 }
@@ -305,6 +306,7 @@ static inline void cr4_clear_bits_irqsoff(unsigned long mask)
 	unsigned long cr4;
 
 	cr4 = this_cpu_read(cpu_tlbstate.cr4);
+	BUG_ON(cr4 != __read_cr4());
 	if ((cr4 & ~mask) != cr4)
 		__cr4_set(cr4 & ~mask);
 }
@@ -334,6 +336,7 @@ static inline void cr4_toggle_bits_irqsoff(unsigned long mask)
 	unsigned long cr4;
 
 	cr4 = this_cpu_read(cpu_tlbstate.cr4);
+        BUG_ON(cr4 != __read_cr4());
 	__cr4_set(cr4 ^ mask);
 }
 
@@ -440,6 +443,7 @@ static inline void __native_flush_tlb_global(void)
 	raw_local_irq_save(flags);
 
 	cr4 = this_cpu_read(cpu_tlbstate.cr4);
+	BUG_ON(cr4 != __read_cr4());
 	/* toggle PGE */
 	native_write_cr4(cr4 ^ X86_CR4_PGE);
 	/* write old PGE again and flush TLBs */
diff --git a/arch/x86/kernel/cpu/common.c b/arch/x86/kernel/cpu/common.c
index 9b3f25e14608..7334852ceb5d 100644
--- a/arch/x86/kernel/cpu/common.c
+++ b/arch/x86/kernel/cpu/common.c
@@ -1895,7 +1895,6 @@ void cpu_init(void)
 	wrmsrl(MSR_KERNEL_GS_BASE, 0);
 	barrier();
 
-	x86_configure_nx();
 	x2apic_setup();
 
 	/*
diff --git a/arch/x86/kernel/process.c b/arch/x86/kernel/process.c
index 571e38c9ee1d..46b1de7883d9 100644
--- a/arch/x86/kernel/process.c
+++ b/arch/x86/kernel/process.c
@@ -42,6 +42,8 @@
 #include <asm/prctl.h>
 #include <asm/spec-ctrl.h>
 #include <asm/proto.h>
+#include <asm/elf.h>
+#include <linux/sizes.h>
 
 #include "process.h"
 
@@ -790,7 +792,10 @@ unsigned long arch_align_stack(unsigned long sp)
 
 unsigned long arch_randomize_brk(struct mm_struct *mm)
 {
-	return randomize_page(mm->brk, 0x02000000);
+	if (mmap_is_ia32())
+		return mm->brk + get_random_long() % SZ_32M + PAGE_SIZE;
+	else
+		return mm->brk + get_random_long() % SZ_1G + PAGE_SIZE;
 }
 
 /*
diff --git a/arch/x86/kernel/sys_x86_64.c b/arch/x86/kernel/sys_x86_64.c
index f7476ce23b6e..652169a2b23a 100644
--- a/arch/x86/kernel/sys_x86_64.c
+++ b/arch/x86/kernel/sys_x86_64.c
@@ -54,13 +54,6 @@ static unsigned long get_align_bits(void)
 	return va_align.bits & get_align_mask();
 }
 
-unsigned long align_vdso_addr(unsigned long addr)
-{
-	unsigned long align_mask = get_align_mask();
-	addr = (addr + align_mask) & ~align_mask;
-	return addr | get_align_bits();
-}
-
 static int __init control_va_addr_alignment(char *str)
 {
 	/* guard against enabling this on other CPU families */
@@ -122,10 +115,7 @@ static void find_start_end(unsigned long addr, unsigned long flags,
 	}
 
 	*begin	= get_mmap_base(1);
-	if (in_32bit_syscall())
-		*end = task_size_32bit();
-	else
-		*end = task_size_64bit(addr > DEFAULT_MAP_WINDOW);
+	*end	= get_mmap_base(0);
 }
 
 unsigned long
@@ -210,7 +200,7 @@ arch_get_unmapped_area_topdown(struct file *filp, const unsigned long addr0,
 
 	info.flags = VM_UNMAPPED_AREA_TOPDOWN;
 	info.length = len;
-	info.low_limit = PAGE_SIZE;
+	info.low_limit = get_mmap_base(1);
 	info.high_limit = get_mmap_base(0);
 
 	/*
diff --git a/arch/x86/mm/init_32.c b/arch/x86/mm/init_32.c
index 0a74407ef92e..5ceff405c81c 100644
--- a/arch/x86/mm/init_32.c
+++ b/arch/x86/mm/init_32.c
@@ -560,9 +560,9 @@ static void __init pagetable_init(void)
 
 #define DEFAULT_PTE_MASK ~(_PAGE_NX | _PAGE_GLOBAL)
 /* Bits supported by the hardware: */
-pteval_t __supported_pte_mask __read_mostly = DEFAULT_PTE_MASK;
+pteval_t __supported_pte_mask __ro_after_init = DEFAULT_PTE_MASK;
 /* Bits allowed in normal kernel mappings: */
-pteval_t __default_kernel_pte_mask __read_mostly = DEFAULT_PTE_MASK;
+pteval_t __default_kernel_pte_mask __ro_after_init = DEFAULT_PTE_MASK;
 EXPORT_SYMBOL_GPL(__supported_pte_mask);
 /* Used in PAGE_KERNEL_* macros which are reasonably used out-of-tree: */
 EXPORT_SYMBOL(__default_kernel_pte_mask);
diff --git a/arch/x86/mm/init_64.c b/arch/x86/mm/init_64.c
index b8541d77452c..a231504e0348 100644
--- a/arch/x86/mm/init_64.c
+++ b/arch/x86/mm/init_64.c
@@ -97,9 +97,9 @@ DEFINE_ENTRY(pte, pte, init)
  */
 
 /* Bits supported by the hardware: */
-pteval_t __supported_pte_mask __read_mostly = ~0;
+pteval_t __supported_pte_mask __ro_after_init = ~0;
 /* Bits allowed in normal kernel mappings: */
-pteval_t __default_kernel_pte_mask __read_mostly = ~0;
+pteval_t __default_kernel_pte_mask __ro_after_init = ~0;
 EXPORT_SYMBOL_GPL(__supported_pte_mask);
 /* Used in PAGE_KERNEL_* macros which are reasonably used out-of-tree: */
 EXPORT_SYMBOL(__default_kernel_pte_mask);
diff --git a/block/blk-softirq.c b/block/blk-softirq.c
index 457d9ba3eb20..5f987fc1c0a0 100644
--- a/block/blk-softirq.c
+++ b/block/blk-softirq.c
@@ -20,7 +20,7 @@ static DEFINE_PER_CPU(struct list_head, blk_cpu_done);
  * Softirq action handler - move entries to local list and loop over them
  * while passing them to the queue registered handler.
  */
-static __latent_entropy void blk_done_softirq(struct softirq_action *h)
+static __latent_entropy void blk_done_softirq(void)
 {
 	struct list_head *cpu_list, local_list;
 
diff --git a/drivers/ata/libata-core.c b/drivers/ata/libata-core.c
index 066b37963ad5..101eadd4c327 100644
--- a/drivers/ata/libata-core.c
+++ b/drivers/ata/libata-core.c
@@ -5141,7 +5141,7 @@ void ata_qc_free(struct ata_queued_cmd *qc)
 	struct ata_port *ap;
 	unsigned int tag;
 
-	WARN_ON_ONCE(qc == NULL); /* ata_qc_from_tag _might_ return NULL */
+	BUG_ON(qc == NULL); /* ata_qc_from_tag _might_ return NULL */
 	ap = qc->ap;
 
 	qc->flags = 0;
@@ -5158,7 +5158,7 @@ void __ata_qc_complete(struct ata_queued_cmd *qc)
 	struct ata_port *ap;
 	struct ata_link *link;
 
-	WARN_ON_ONCE(qc == NULL); /* ata_qc_from_tag _might_ return NULL */
+	BUG_ON(qc == NULL); /* ata_qc_from_tag _might_ return NULL */
 	WARN_ON_ONCE(!(qc->flags & ATA_QCFLAG_ACTIVE));
 	ap = qc->ap;
 	link = qc->dev->link;
diff --git a/drivers/char/Kconfig b/drivers/char/Kconfig
index df0fc997dc3e..bd8eed8de6c1 100644
--- a/drivers/char/Kconfig
+++ b/drivers/char/Kconfig
@@ -9,7 +9,6 @@ source "drivers/tty/Kconfig"
 
 config DEVMEM
 	bool "/dev/mem virtual device support"
-	default y
 	help
 	  Say Y here if you want to support the /dev/mem device.
 	  The /dev/mem device is used to access areas of physical
@@ -514,7 +513,6 @@ config TELCLOCK
 config DEVPORT
 	bool "/dev/port character device"
 	depends on ISA || PCI
-	default y
 	help
 	  Say Y here if you want to support the /dev/port device. The /dev/port
 	  device is similar to /dev/mem, but for I/O ports.
diff --git a/drivers/tty/Kconfig b/drivers/tty/Kconfig
index c7623f99ac0f..859c2782c8e2 100644
--- a/drivers/tty/Kconfig
+++ b/drivers/tty/Kconfig
@@ -122,7 +122,6 @@ config UNIX98_PTYS
 
 config LEGACY_PTYS
 	bool "Legacy (BSD) PTY support"
-	default y
 	---help---
 	  A pseudo terminal (PTY) is a software device consisting of two
 	  halves: a master and a slave. The slave device behaves identical to
diff --git a/drivers/tty/tty_io.c b/drivers/tty/tty_io.c
index 36c1c59cc72a..55cd2979d2ab 100644
--- a/drivers/tty/tty_io.c
+++ b/drivers/tty/tty_io.c
@@ -173,6 +173,7 @@ static void free_tty_struct(struct tty_struct *tty)
 	put_device(tty->dev);
 	kfree(tty->write_buf);
 	tty->magic = 0xDEADDEAD;
+	put_user_ns(tty->owner_user_ns);
 	kfree(tty);
 }
 
@@ -2180,11 +2181,19 @@ static int tty_fasync(int fd, struct file *filp, int on)
  *	FIXME: may race normal receive processing
  */
 
+int tiocsti_restrict = IS_ENABLED(CONFIG_SECURITY_TIOCSTI_RESTRICT);
+
 static int tiocsti(struct tty_struct *tty, char __user *p)
 {
 	char ch, mbz = 0;
 	struct tty_ldisc *ld;
 
+	if (tiocsti_restrict &&
+		!ns_capable(tty->owner_user_ns, CAP_SYS_ADMIN)) {
+		dev_warn_ratelimited(tty->dev,
+			"Denied TIOCSTI ioctl for non-privileged process\n");
+		return -EPERM;
+	}
 	if ((current->signal->tty != tty) && !capable(CAP_SYS_ADMIN))
 		return -EPERM;
 	if (get_user(ch, p))
@@ -3006,6 +3015,7 @@ struct tty_struct *alloc_tty_struct(struct tty_driver *driver, int idx)
 	tty->index = idx;
 	tty_line_name(driver, idx, tty->name);
 	tty->dev = tty_get_device(tty);
+	tty->owner_user_ns = get_user_ns(current_user_ns());
 
 	return tty;
 }
diff --git a/drivers/usb/core/hub.c b/drivers/usb/core/hub.c
index 4d3de33885ff..4aa21cd2531a 100644
--- a/drivers/usb/core/hub.c
+++ b/drivers/usb/core/hub.c
@@ -45,6 +45,8 @@
 #define USB_TP_TRANSMISSION_DELAY	40	/* ns */
 #define USB_TP_TRANSMISSION_DELAY_MAX	65535	/* ns */
 
+extern int deny_new_usb;
+
 /* Protect struct usb_device->state and ->children members
  * Note: Both are also protected by ->dev.sem, except that ->state can
  * change to USB_STATE_NOTATTACHED even when the semaphore isn't held. */
@@ -5014,6 +5016,12 @@ static void hub_port_connect(struct usb_hub *hub, int port1, u16 portstatus,
 			goto done;
 		return;
 	}
+
+	if (deny_new_usb) {
+		dev_err(&port_dev->dev, "denied insert of USB device on port %d\n", port1);
+		goto done;
+	}
+
 	if (hub_is_superspeed(hub->hdev))
 		unit_load = 150;
 	else
diff --git a/fs/exec.c b/fs/exec.c
index d62cd1d71098..75326d3e4a89 100644
--- a/fs/exec.c
+++ b/fs/exec.c
@@ -63,6 +63,7 @@
 #include <linux/oom.h>
 #include <linux/compat.h>
 #include <linux/vmalloc.h>
+#include <linux/random.h>
 
 #include <linux/uaccess.h>
 #include <asm/mmu_context.h>
@@ -276,6 +277,8 @@ static int __bprm_mm_init(struct linux_binprm *bprm)
 	arch_bprm_mm_init(mm, vma);
 	up_write(&mm->mmap_sem);
 	bprm->p = vma->vm_end - sizeof(void *);
+	if (randomize_va_space)
+		bprm->p ^= get_random_int() & ~PAGE_MASK;
 	return 0;
 err:
 	up_write(&mm->mmap_sem);
diff --git a/fs/namei.c b/fs/namei.c
index 5b5759d70822..63ab73f6121c 100644
--- a/fs/namei.c
+++ b/fs/namei.c
@@ -877,10 +877,10 @@ static inline void put_link(struct nameidata *nd)
 		path_put(&last->link);
 }
 
-int sysctl_protected_symlinks __read_mostly = 1;
-int sysctl_protected_hardlinks __read_mostly = 1;
-int sysctl_protected_fifos __read_mostly;
-int sysctl_protected_regular __read_mostly;
+int sysctl_protected_symlinks __read_mostly = 1;
+int sysctl_protected_hardlinks __read_mostly = 1;
+int sysctl_protected_fifos __read_mostly = 2;
+int sysctl_protected_regular __read_mostly = 2;
 
 /**
  * may_follow_link - Check symlink following for unsafe situations
diff --git a/fs/nfs/Kconfig b/fs/nfs/Kconfig
index e7dd07f47825..2b357b4355fd 100644
--- a/fs/nfs/Kconfig
+++ b/fs/nfs/Kconfig
@@ -195,4 +195,3 @@ config NFS_DEBUG
 	bool
 	depends on NFS_FS && SUNRPC_DEBUG
 	select CRC32
-	default y
diff --git a/fs/proc/Kconfig b/fs/proc/Kconfig
index cb5629bd5fff..bc44606fcc48 100644
--- a/fs/proc/Kconfig
+++ b/fs/proc/Kconfig
@@ -41,7 +41,6 @@ config PROC_KCORE
 config PROC_VMCORE
 	bool "/proc/vmcore support"
 	depends on PROC_FS && CRASH_DUMP
-	default y
         help
         Exports the dump image of crashed kernel in ELF format.
 
diff --git a/fs/stat.c b/fs/stat.c
index c38e4c2e1221..6135fbaf7298 100644
--- a/fs/stat.c
+++ b/fs/stat.c
@@ -40,8 +40,13 @@ void generic_fillattr(struct inode *inode, struct kstat *stat)
 	stat->gid = inode->i_gid;
 	stat->rdev = inode->i_rdev;
 	stat->size = i_size_read(inode);
-	stat->atime = inode->i_atime;
-	stat->mtime = inode->i_mtime;
+	if (is_sidechannel_device(inode) && !capable_noaudit(CAP_MKNOD)) {
+		stat->atime = inode->i_ctime;
+		stat->mtime = inode->i_ctime;
+	} else {
+		stat->atime = inode->i_atime;
+		stat->mtime = inode->i_mtime;
+	}
 	stat->ctime = inode->i_ctime;
 	stat->blksize = i_blocksize(inode);
 	stat->blocks = inode->i_blocks;
@@ -77,9 +82,14 @@ int vfs_getattr_nosec(const struct path *path, struct kstat *stat,
 	if (IS_AUTOMOUNT(inode))
 		stat->attributes |= STATX_ATTR_AUTOMOUNT;
 
-	if (inode->i_op->getattr)
-		return inode->i_op->getattr(path, stat, request_mask,
-					    query_flags);
+	if (inode->i_op->getattr) {
+		int retval = inode->i_op->getattr(path, stat, request_mask, query_flags);
+		if (!retval && is_sidechannel_device(inode) && !capable_noaudit(CAP_MKNOD)) {
+			stat->atime = stat->ctime;
+			stat->mtime = stat->ctime;
+		}
+		return retval;
+	}
 
 	generic_fillattr(inode, stat);
 	return 0;
diff --git a/fs/userfaultfd.c b/fs/userfaultfd.c
index d99d166fd892..7a4f2854feb8 100644
--- a/fs/userfaultfd.c
+++ b/fs/userfaultfd.c
@@ -28,7 +28,11 @@
 #include <linux/security.h>
 #include <linux/hugetlb.h>
 
+#ifdef CONFIG_USERFAULTFD_UNPRIVILEGED
 int sysctl_unprivileged_userfaultfd __read_mostly = 1;
+#else
+int sysctl_unprivileged_userfaultfd __read_mostly;
+#endif
 
 static struct kmem_cache *userfaultfd_ctx_cachep __read_mostly;
 
diff --git a/include/linux/cache.h b/include/linux/cache.h
index 750621e41d1c..e7157c18c62c 100644
--- a/include/linux/cache.h
+++ b/include/linux/cache.h
@@ -31,6 +31,8 @@
 #define __ro_after_init __attribute__((__section__(".data..ro_after_init")))
 #endif
 
+#define __read_only __ro_after_init
+
 #ifndef ____cacheline_aligned
 #define ____cacheline_aligned __attribute__((__aligned__(SMP_CACHE_BYTES)))
 #endif
diff --git a/include/linux/capability.h b/include/linux/capability.h
index ecce0f43c73a..e46306dd4401 100644
--- a/include/linux/capability.h
+++ b/include/linux/capability.h
@@ -208,6 +208,7 @@ extern bool has_capability_noaudit(struct task_struct *t, int cap);
 extern bool has_ns_capability_noaudit(struct task_struct *t,
 				      struct user_namespace *ns, int cap);
 extern bool capable(int cap);
+extern bool capable_noaudit(int cap);
 extern bool ns_capable(struct user_namespace *ns, int cap);
 extern bool ns_capable_noaudit(struct user_namespace *ns, int cap);
 extern bool ns_capable_setid(struct user_namespace *ns, int cap);
@@ -234,6 +235,10 @@ static inline bool capable(int cap)
 {
 	return true;
 }
+static inline bool capable_noaudit(int cap)
+{
+	return true;
+}
 static inline bool ns_capable(struct user_namespace *ns, int cap)
 {
 	return true;
diff --git a/include/linux/fs.h b/include/linux/fs.h
index 4c82683e034a..560901350ab5 100644
--- a/include/linux/fs.h
+++ b/include/linux/fs.h
@@ -3632,4 +3632,15 @@ static inline int inode_drain_writes(struct inode *inode)
 	return filemap_write_and_wait(inode->i_mapping);
 }
 
+extern int device_sidechannel_restrict;
+
+static inline bool is_sidechannel_device(const struct inode *inode)
+{
+	umode_t mode;
+	if (!device_sidechannel_restrict)
+		return false;
+	mode = inode->i_mode;
+	return ((S_ISCHR(mode) || S_ISBLK(mode)) && (mode & (S_IROTH | S_IWOTH)));
+}
+
 #endif /* _LINUX_FS_H */
diff --git a/include/linux/fsnotify.h b/include/linux/fsnotify.h
index a2d5d175d3c1..e91ab06119b0 100644
--- a/include/linux/fsnotify.h
+++ b/include/linux/fsnotify.h
@@ -233,6 +233,9 @@ static inline void fsnotify_access(struct file *file)
 	struct inode *inode = file_inode(file);
 	__u32 mask = FS_ACCESS;
 
+	if (is_sidechannel_device(inode))
+		return;
+
 	if (S_ISDIR(inode->i_mode))
 		mask |= FS_ISDIR;
 
@@ -249,6 +252,9 @@ static inline void fsnotify_modify(struct file *file)
 	struct inode *inode = file_inode(file);
 	__u32 mask = FS_MODIFY;
 
+	if (is_sidechannel_device(inode))
+		return;
+
 	if (S_ISDIR(inode->i_mode))
 		mask |= FS_ISDIR;
 
diff --git a/include/linux/gfp.h b/include/linux/gfp.h
index 61f2f6ff9467..f9b3e3d675ae 100644
--- a/include/linux/gfp.h
+++ b/include/linux/gfp.h
@@ -553,9 +553,9 @@ extern struct page *alloc_pages_vma(gfp_t gfp_mask, int order,
 extern unsigned long __get_free_pages(gfp_t gfp_mask, unsigned int order);
 extern unsigned long get_zeroed_page(gfp_t gfp_mask);
 
-void *alloc_pages_exact(size_t size, gfp_t gfp_mask);
+void *alloc_pages_exact(size_t size, gfp_t gfp_mask) __attribute__((alloc_size(1)));
 void free_pages_exact(void *virt, size_t size);
-void * __meminit alloc_pages_exact_nid(int nid, size_t size, gfp_t gfp_mask);
+void * __meminit alloc_pages_exact_nid(int nid, size_t size, gfp_t gfp_mask) __attribute__((alloc_size(2)));
 
 #define __get_free_page(gfp_mask) \
 		__get_free_pages((gfp_mask), 0)
diff --git a/include/linux/highmem.h b/include/linux/highmem.h
index ea5cdbd8c2c3..805b84d6bbca 100644
--- a/include/linux/highmem.h
+++ b/include/linux/highmem.h
@@ -215,6 +215,13 @@ static inline void clear_highpage(struct page *page)
 	kunmap_atomic(kaddr);
 }
 
+static inline void verify_zero_highpage(struct page *page)
+{
+	void *kaddr = kmap_atomic(page);
+	BUG_ON(memchr_inv(kaddr, 0, PAGE_SIZE));
+	kunmap_atomic(kaddr);
+}
+
 static inline void zero_user_segments(struct page *page,
 	unsigned start1, unsigned end1,
 	unsigned start2, unsigned end2)
diff --git a/include/linux/interrupt.h b/include/linux/interrupt.h
index 89fc59dab57d..5f98e14e9470 100644
--- a/include/linux/interrupt.h
+++ b/include/linux/interrupt.h
@@ -540,7 +540,7 @@ extern const char * const softirq_to_name[NR_SOFTIRQS];
 
 struct softirq_action
 {
-	void	(*action)(struct softirq_action *);
+	void	(*action)(void);
 };
 
 asmlinkage void do_softirq(void);
@@ -555,7 +555,7 @@ static inline void do_softirq_own_stack(void)
 }
 #endif
 
-extern void open_softirq(int nr, void (*action)(struct softirq_action *));
+extern void __init open_softirq(int nr, void (*action)(void));
 extern void softirq_init(void);
 extern void __raise_softirq_irqoff(unsigned int nr);
 
diff --git a/include/linux/kobject_ns.h b/include/linux/kobject_ns.h
index 069aa2ebef90..cb9e3637a620 100644
--- a/include/linux/kobject_ns.h
+++ b/include/linux/kobject_ns.h
@@ -45,7 +45,7 @@ struct kobj_ns_type_operations {
 	void (*drop_ns)(void *);
 };
 
-int kobj_ns_type_register(const struct kobj_ns_type_operations *ops);
+int __init kobj_ns_type_register(const struct kobj_ns_type_operations *ops);
 int kobj_ns_type_registered(enum kobj_ns_type type);
 const struct kobj_ns_type_operations *kobj_child_ns_ops(struct kobject *parent);
 const struct kobj_ns_type_operations *kobj_ns_ops(struct kobject *kobj);
diff --git a/include/linux/mm.h b/include/linux/mm.h
index 3285dae06c03..de056fc1e272 100644
--- a/include/linux/mm.h
+++ b/include/linux/mm.h
@@ -664,7 +664,7 @@ static inline int is_vmalloc_or_module_addr(const void *x)
 }
 #endif
 
-extern void *kvmalloc_node(size_t size, gfp_t flags, int node);
+extern void *kvmalloc_node(size_t size, gfp_t flags, int node) __attribute__((alloc_size(1)));
 static inline void *kvmalloc(size_t size, gfp_t flags)
 {
 	return kvmalloc_node(size, flags, NUMA_NO_NODE);
diff --git a/include/linux/percpu.h b/include/linux/percpu.h
index 5e76af742c80..9a6c682ec127 100644
--- a/include/linux/percpu.h
+++ b/include/linux/percpu.h
@@ -123,7 +123,7 @@ extern int __init pcpu_page_first_chunk(size_t reserved_size,
 				pcpu_fc_populate_pte_fn_t populate_pte_fn);
 #endif
 
-extern void __percpu *__alloc_reserved_percpu(size_t size, size_t align);
+extern void __percpu *__alloc_reserved_percpu(size_t size, size_t align) __attribute__((alloc_size(1)));
 extern bool __is_kernel_percpu_address(unsigned long addr, unsigned long *can_addr);
 extern bool is_kernel_percpu_address(unsigned long addr);
 
@@ -131,8 +131,8 @@ extern bool is_kernel_percpu_address(unsigned long addr);
 extern void __init setup_per_cpu_areas(void);
 #endif
 
-extern void __percpu *__alloc_percpu_gfp(size_t size, size_t align, gfp_t gfp);
-extern void __percpu *__alloc_percpu(size_t size, size_t align);
+extern void __percpu *__alloc_percpu_gfp(size_t size, size_t align, gfp_t gfp) __attribute__((alloc_size(1)));
+extern void __percpu *__alloc_percpu(size_t size, size_t align) __attribute__((alloc_size(1)));
 extern void free_percpu(void __percpu *__pdata);
 extern phys_addr_t per_cpu_ptr_to_phys(void *addr);
 
diff --git a/include/linux/perf_event.h b/include/linux/perf_event.h
index 68ccc5b1913b..a7565ea44938 100644
--- a/include/linux/perf_event.h
+++ b/include/linux/perf_event.h
@@ -1241,6 +1241,11 @@ extern int perf_cpu_time_max_percent_handler(struct ctl_table *table, int write,
 int perf_event_max_stack_handler(struct ctl_table *table, int write,
 				 void __user *buffer, size_t *lenp, loff_t *ppos);
 
+static inline bool perf_paranoid_any(void)
+{
+	return sysctl_perf_event_paranoid > 2;
+}
+
 static inline bool perf_paranoid_tracepoint_raw(void)
 {
 	return sysctl_perf_event_paranoid > -1;
diff --git a/include/linux/slab.h b/include/linux/slab.h
index 4d2a2fa55ed5..be3a8234edde 100644
--- a/include/linux/slab.h
+++ b/include/linux/slab.h
@@ -184,8 +184,8 @@ void memcg_deactivate_kmem_caches(struct mem_cgroup *, struct mem_cgroup *);
 /*
  * Common kmalloc functions provided by all allocators
  */
-void * __must_check __krealloc(const void *, size_t, gfp_t);
-void * __must_check krealloc(const void *, size_t, gfp_t);
+void * __must_check __krealloc(const void *, size_t, gfp_t) __attribute__((alloc_size(2)));
+void * __must_check krealloc(const void *, size_t, gfp_t) __attribute((alloc_size(2)));
 void kfree(const void *);
 void kzfree(const void *);
 size_t __ksize(const void *);
@@ -390,7 +390,7 @@ static __always_inline unsigned int kmalloc_index(size_t size)
 }
 #endif /* !CONFIG_SLOB */
 
-void *__kmalloc(size_t size, gfp_t flags) __assume_kmalloc_alignment __malloc;
+void *__kmalloc(size_t size, gfp_t flags) __assume_kmalloc_alignment __malloc __attribute__((alloc_size(1)));
 void *kmem_cache_alloc(struct kmem_cache *, gfp_t flags) __assume_slab_alignment __malloc;
 void kmem_cache_free(struct kmem_cache *, void *);
 
@@ -414,7 +414,7 @@ static __always_inline void kfree_bulk(size_t size, void **p)
 }
 
 #ifdef CONFIG_NUMA
-void *__kmalloc_node(size_t size, gfp_t flags, int node) __assume_kmalloc_alignment __malloc;
+void *__kmalloc_node(size_t size, gfp_t flags, int node) __assume_kmalloc_alignment __malloc __attribute__((alloc_size(1)));
 void *kmem_cache_alloc_node(struct kmem_cache *, gfp_t flags, int node) __assume_slab_alignment __malloc;
 #else
 static __always_inline void *__kmalloc_node(size_t size, gfp_t flags, int node)
@@ -539,7 +539,7 @@ static __always_inline void *kmalloc_large(size_t size, gfp_t flags)
  *	Try really hard to succeed the allocation but fail
  *	eventually.
  */
-static __always_inline void *kmalloc(size_t size, gfp_t flags)
+static __always_inline __attribute__((alloc_size(1))) void *kmalloc(size_t size, gfp_t flags)
 {
 	if (__builtin_constant_p(size)) {
 #ifndef CONFIG_SLOB
@@ -581,7 +581,7 @@ static __always_inline unsigned int kmalloc_size(unsigned int n)
 	return 0;
 }
 
-static __always_inline void *kmalloc_node(size_t size, gfp_t flags, int node)
+static __always_inline __attribute__((alloc_size(1))) void *kmalloc_node(size_t size, gfp_t flags, int node)
 {
 #ifndef CONFIG_SLOB
 	if (__builtin_constant_p(size) &&
diff --git a/include/linux/slub_def.h b/include/linux/slub_def.h
index d2153789bd9f..97da977d6060 100644
--- a/include/linux/slub_def.h
+++ b/include/linux/slub_def.h
@@ -121,6 +121,11 @@ struct kmem_cache {
 	unsigned long random;
 #endif
 
+#ifdef CONFIG_SLAB_CANARY
+	unsigned long random_active;
+	unsigned long random_inactive;
+#endif
+
 #ifdef CONFIG_NUMA
 	/*
 	 * Defragmentation by allocating from a remote node.
diff --git a/include/linux/string.h b/include/linux/string.h
index b2264355272d..2115131ba73f 100644
--- a/include/linux/string.h
+++ b/include/linux/string.h
@@ -268,6 +268,12 @@ void __read_overflow2(void) __compiletime_error("detected read beyond size of ob
 void __read_overflow3(void) __compiletime_error("detected read beyond size of object passed as 3rd parameter");
 void __write_overflow(void) __compiletime_error("detected write beyond size of object passed as 1st parameter");
 
+#ifdef CONFIG_FORTIFY_SOURCE_STRICT_STRING
+#define __string_size(p) __builtin_object_size(p, 1)
+#else
+#define __string_size(p) __builtin_object_size(p, 0)
+#endif
+
 #if !defined(__NO_FORTIFY) && defined(__OPTIMIZE__) && defined(CONFIG_FORTIFY_SOURCE)
 
 #ifdef CONFIG_KASAN
@@ -296,7 +302,7 @@ extern char *__underlying_strncpy(char *p, const char *q, __kernel_size_t size)
 
 __FORTIFY_INLINE char *strncpy(char *p, const char *q, __kernel_size_t size)
 {
-	size_t p_size = __builtin_object_size(p, 0);
+	size_t p_size = __string_size(p);
 	if (__builtin_constant_p(size) && p_size < size)
 		__write_overflow();
 	if (p_size < size)
@@ -306,7 +312,7 @@ __FORTIFY_INLINE char *strncpy(char *p, const char *q, __kernel_size_t size)
 
 __FORTIFY_INLINE char *strcat(char *p, const char *q)
 {
-	size_t p_size = __builtin_object_size(p, 0);
+	size_t p_size = __string_size(p);
 	if (p_size == (size_t)-1)
 		return __underlying_strcat(p, q);
 	if (strlcat(p, q, p_size) >= p_size)
@@ -317,7 +323,7 @@ __FORTIFY_INLINE char *strcat(char *p, const char *q)
 __FORTIFY_INLINE __kernel_size_t strlen(const char *p)
 {
 	__kernel_size_t ret;
-	size_t p_size = __builtin_object_size(p, 0);
+	size_t p_size = __string_size(p);
 
 	/* Work around gcc excess stack consumption issue */
 	if (p_size == (size_t)-1 ||
@@ -332,7 +338,7 @@ __FORTIFY_INLINE __kernel_size_t strlen(const char *p)
 extern __kernel_size_t __real_strnlen(const char *, __kernel_size_t) __RENAME(strnlen);
 __FORTIFY_INLINE __kernel_size_t strnlen(const char *p, __kernel_size_t maxlen)
 {
-	size_t p_size = __builtin_object_size(p, 0);
+	size_t p_size = __string_size(p);
 	__kernel_size_t ret = __real_strnlen(p, maxlen < p_size ? maxlen : p_size);
 	if (p_size <= ret && maxlen != ret)
 		fortify_panic(__func__);
@@ -344,8 +350,8 @@ extern size_t __real_strlcpy(char *, const char *, size_t) __RENAME(strlcpy);
 __FORTIFY_INLINE size_t strlcpy(char *p, const char *q, size_t size)
 {
 	size_t ret;
-	size_t p_size = __builtin_object_size(p, 0);
-	size_t q_size = __builtin_object_size(q, 0);
+	size_t p_size = __string_size(p);
+	size_t q_size = __string_size(q);
 	if (p_size == (size_t)-1 && q_size == (size_t)-1)
 		return __real_strlcpy(p, q, size);
 	ret = strlen(q);
@@ -365,8 +371,8 @@ __FORTIFY_INLINE size_t strlcpy(char *p, const char *q, size_t size)
 __FORTIFY_INLINE char *strncat(char *p, const char *q, __kernel_size_t count)
 {
 	size_t p_len, copy_len;
-	size_t p_size = __builtin_object_size(p, 0);
-	size_t q_size = __builtin_object_size(q, 0);
+	size_t p_size = __string_size(p);
+	size_t q_size = __string_size(q);
 	if (p_size == (size_t)-1 && q_size == (size_t)-1)
 		return __underlying_strncat(p, q, count);
 	p_len = strlen(p);
@@ -479,8 +485,8 @@ __FORTIFY_INLINE void *kmemdup(const void *p, size_t size, gfp_t gfp)
 /* defined after fortified strlen and memcpy to reuse them */
 __FORTIFY_INLINE char *strcpy(char *p, const char *q)
 {
-	size_t p_size = __builtin_object_size(p, 0);
-	size_t q_size = __builtin_object_size(q, 0);
+	size_t p_size = __string_size(p);
+	size_t q_size = __string_size(q);
 	if (p_size == (size_t)-1 && q_size == (size_t)-1)
 		return __underlying_strcpy(p, q);
 	memcpy(p, q, strlen(q) + 1);
diff --git a/include/linux/tty.h b/include/linux/tty.h
index a99e9b8e4e31..ee272abea5f9 100644
--- a/include/linux/tty.h
+++ b/include/linux/tty.h
@@ -14,6 +14,7 @@
 #include <uapi/linux/tty.h>
 #include <linux/rwsem.h>
 #include <linux/llist.h>
+#include <linux/user_namespace.h>
 
 
 /*
@@ -338,6 +339,7 @@ struct tty_struct {
 	/* If the tty has a pending do_SAK, queue it here - akpm */
 	struct work_struct SAK_work;
 	struct tty_port *port;
+	struct user_namespace *owner_user_ns;
 } __randomize_layout;
 
 /* Each of a tty's open files has private_data pointing to tty_file_private */
@@ -347,6 +349,8 @@ struct tty_file_private {
 	struct list_head list;
 };
 
+extern int tiocsti_restrict;
+
 /* tty magic number */
 #define TTY_MAGIC		0x5401
 
diff --git a/include/linux/vmalloc.h b/include/linux/vmalloc.h
index 01a1334c5fc5..576e00382884 100644
--- a/include/linux/vmalloc.h
+++ b/include/linux/vmalloc.h
@@ -88,19 +88,19 @@ static inline void vmalloc_init(void)
 static inline unsigned long vmalloc_nr_pages(void) { return 0; }
 #endif
 
-extern void *vmalloc(unsigned long size);
-extern void *vzalloc(unsigned long size);
-extern void *vmalloc_user(unsigned long size);
-extern void *vmalloc_node(unsigned long size, int node);
-extern void *vzalloc_node(unsigned long size, int node);
-extern void *vmalloc_exec(unsigned long size);
-extern void *vmalloc_32(unsigned long size);
-extern void *vmalloc_32_user(unsigned long size);
-extern void *__vmalloc(unsigned long size, gfp_t gfp_mask, pgprot_t prot);
+extern void *vmalloc(unsigned long size) __attribute__((alloc_size(1)));
+extern void *vzalloc(unsigned long size) __attribute__((alloc_size(1)));
+extern void *vmalloc_user(unsigned long size) __attribute__((alloc_size(1)));
+extern void *vmalloc_node(unsigned long size, int node) __attribute__((alloc_size(1)));
+extern void *vzalloc_node(unsigned long size, int node) __attribute__((alloc_size(1)));
+extern void *vmalloc_exec(unsigned long size) __attribute__((alloc_size(1)));
+extern void *vmalloc_32(unsigned long size) __attribute__((alloc_size(1)));
+extern void *vmalloc_32_user(unsigned long size) __attribute__((alloc_size(1)));
+extern void *__vmalloc(unsigned long size, gfp_t gfp_mask, pgprot_t prot) __attribute__((alloc_size(1)));
 extern void *__vmalloc_node_range(unsigned long size, unsigned long align,
 			unsigned long start, unsigned long end, gfp_t gfp_mask,
 			pgprot_t prot, unsigned long vm_flags, int node,
-			const void *caller);
+			const void *caller) __attribute__((alloc_size(1)));
 #ifndef CONFIG_MMU
 extern void *__vmalloc_node_flags(unsigned long size, int node, gfp_t flags);
 static inline void *__vmalloc_node_flags_caller(unsigned long size, int node,
diff --git a/include/net/tcp.h b/include/net/tcp.h
index 377179283c46..3b4282e81fa8 100644
--- a/include/net/tcp.h
+++ b/include/net/tcp.h
@@ -242,6 +242,7 @@ void tcp_time_wait(struct sock *sk, int state, int timeo);
 /* sysctl variables for tcp */
 extern int sysctl_tcp_max_orphans;
 extern long sysctl_tcp_mem[3];
+extern int sysctl_tcp_simult_connect;
 
 #define TCP_RACK_LOSS_DETECTION  0x1 /* Use RACK to detect losses */
 #define TCP_RACK_STATIC_REO_WND  0x2 /* Use static RACK reo wnd */
diff --git a/init/Kconfig b/init/Kconfig
index 6db3e310a5e4..86dd372b13e3 100644
--- a/init/Kconfig
+++ b/init/Kconfig
@@ -346,6 +346,7 @@ config USELIB
 config AUDIT
 	bool "Auditing support"
 	depends on NET
+	default y
 	help
 	  Enable auditing infrastructure that can be used with another
 	  kernel subsystem, such as SELinux (which requires this for
@@ -1083,6 +1084,22 @@ config USER_NS
 
 	  If unsure, say N.
 
+config USER_NS_UNPRIVILEGED
+	bool "Allow unprivileged users to create namespaces"
+	depends on USER_NS
+	default n
+	help
+	  When disabled, unprivileged users will not be able to create
+	  new namespaces. Allowing users to create their own namespaces
+	  has been part of several recent local privilege escalation
+	  exploits, so if you need user namespaces but are
+	  paranoid^Wsecurity-conscious you want to disable this.
+
+	  This setting can be overridden at runtime via the
+	  kernel.unprivileged_userns_clone sysctl.
+
+	  If unsure, say N.
+
 config PID_NS
 	bool "PID Namespaces"
 	default y
@@ -1501,8 +1518,7 @@ config SHMEM
 	  which may be appropriate on small systems without swap.
 
 config AIO
-	bool "Enable AIO support" if EXPERT
-	default y
+	bool "Enable AIO support"
 	help
 	  This option enables POSIX asynchronous I/O which may by used
 	  by some high performance threaded applications. Disabling
@@ -1613,6 +1629,23 @@ config USERFAULTFD
 	  Enable the userfaultfd() system call that allows to intercept and
 	  handle page faults in userland.
 
+config USERFAULTFD_UNPRIVILEGED
+	bool "Allow unprivileged users to use the userfaultfd syscall"
+	depends on USERFAULTFD
+	default n
+	help
+	  When disabled, unprivileged users will not be able to use the userfaultfd
+	  syscall. Userfaultfd provide attackers with a way to stall a kernel
+	  thread in the middle of memory accesses from userspace by initiating an
+	  access on an unmapped page. To avoid various heap grooming and heap
+	  spraying techniques for exploiting use-after-free flaws this should be
+	  disabled by default.
+
+	  This setting can be overridden at runtime via the
+	  vm.unprivileged_userfaultfd sysctl.
+
+	  If unsure, say N.
+
 config ARCH_HAS_MEMBARRIER_CALLBACKS
 	bool
 
@@ -1725,7 +1758,7 @@ config VM_EVENT_COUNTERS
 
 config SLUB_DEBUG
 	default y
-	bool "Enable SLUB debugging support" if EXPERT
+	bool "Enable SLUB debugging support"
 	depends on SLUB && SYSFS
 	help
 	  SLUB has extensive debug support features. Disabling these can
@@ -1749,7 +1782,6 @@ config SLUB_MEMCG_SYSFS_ON
 
 config COMPAT_BRK
 	bool "Disable heap randomization"
-	default y
 	help
 	  Randomizing heap placement makes heap exploits harder, but it
 	  also breaks ancient binaries (including anything libc5 based).
@@ -1796,7 +1828,6 @@ endchoice
 
 config SLAB_MERGE_DEFAULT
 	bool "Allow slab caches to be merged"
-	default y
 	help
 	  For reduced kernel memory fragmentation, slab caches can be
 	  merged when they share the same size and other characteristics.
@@ -1809,9 +1840,9 @@ config SLAB_MERGE_DEFAULT
 	  command line.
 
 config SLAB_FREELIST_RANDOM
-	default n
 	depends on SLAB || SLUB
 	bool "SLAB freelist randomization"
+	default y
 	help
 	  Randomizes the freelist order used on creating new pages. This
 	  security feature reduces the predictability of the kernel slab
@@ -1820,12 +1851,30 @@ config SLAB_FREELIST_RANDOM
 config SLAB_FREELIST_HARDENED
 	bool "Harden slab freelist metadata"
 	depends on SLUB
+	default y
 	help
 	  Many kernel heap attacks try to target slab cache metadata and
 	  other infrastructure. This options makes minor performance
 	  sacrifices to harden the kernel slab allocator against common
 	  freelist exploit methods.
 
+config SLAB_CANARY
+	depends on SLUB
+	depends on !SLAB_MERGE_DEFAULT
+	bool "SLAB canaries"
+	default y
+	help
+	  Place canaries at the end of kernel slab allocations, sacrificing
+	  some performance and memory usage for security.
+
+	  Canaries can detect some forms of heap corruption when allocations
+	  are freed and as part of the HARDENED_USERCOPY feature. It provides
+	  basic use-after-free detection for HARDENED_USERCOPY.
+
+	  Canaries absorb small overflows (rendering them harmless), mitigate
+	  non-NUL terminated C string overflows on 64-bit via a guaranteed zero
+	  byte and provide basic double-free detection.
+
 config SHUFFLE_PAGE_ALLOCATOR
 	bool "Page allocator randomization"
 	default SLAB_FREELIST_RANDOM && ACPI_NUMA
diff --git a/kernel/audit.c b/kernel/audit.c
index 05ae208ad442..b728d39173dc 100644
--- a/kernel/audit.c
+++ b/kernel/audit.c
@@ -1641,6 +1641,9 @@ static int __init audit_enable(char *str)
 
 	if (audit_default == AUDIT_OFF)
 		audit_initialized = AUDIT_DISABLED;
+	else if (!audit_ever_enabled)
+		audit_initialized = AUDIT_UNINITIALIZED;
+
 	if (audit_set_enabled(audit_default))
 		pr_err("audit: error setting audit state (%d)\n",
 		       audit_default);
diff --git a/kernel/bpf/core.c b/kernel/bpf/core.c
index ef0e1e3e66f4..d1ddc8695ab8 100644
--- a/kernel/bpf/core.c
+++ b/kernel/bpf/core.c
@@ -519,7 +519,7 @@ void bpf_prog_kallsyms_del_all(struct bpf_prog *fp)
 #ifdef CONFIG_BPF_JIT
 /* All BPF JIT sysctl knobs here. */
 int bpf_jit_enable   __read_mostly = IS_BUILTIN(CONFIG_BPF_JIT_ALWAYS_ON);
-int bpf_jit_harden   __read_mostly;
+int bpf_jit_harden   __read_mostly = 2;
 int bpf_jit_kallsyms __read_mostly;
 long bpf_jit_limit   __read_mostly;
 
diff --git a/kernel/bpf/syscall.c b/kernel/bpf/syscall.c
index bf03d04a9e2f..db80f95875cd 100644
--- a/kernel/bpf/syscall.c
+++ b/kernel/bpf/syscall.c
@@ -39,7 +39,7 @@ static DEFINE_SPINLOCK(prog_idr_lock);
 static DEFINE_IDR(map_idr);
 static DEFINE_SPINLOCK(map_idr_lock);
 
-int sysctl_unprivileged_bpf_disabled __read_mostly;
+int sysctl_unprivileged_bpf_disabled __read_mostly = 1;
 
 static const struct bpf_map_ops * const bpf_map_types[] = {
 #define BPF_PROG_TYPE(_id, _ops)
diff --git a/kernel/capability.c b/kernel/capability.c
index 1444f3954d75..8cc9dd7992f2 100644
--- a/kernel/capability.c
+++ b/kernel/capability.c
@@ -449,6 +449,12 @@ bool capable(int cap)
 	return ns_capable(&init_user_ns, cap);
 }
 EXPORT_SYMBOL(capable);
+
+bool capable_noaudit(int cap)
+{
+	return ns_capable_noaudit(&init_user_ns, cap);
+}
+EXPORT_SYMBOL(capable_noaudit);
 #endif /* CONFIG_MULTIUSER */
 
 /**
diff --git a/kernel/events/core.c b/kernel/events/core.c
index db1f5aa755f2..0f2d54cfe02e 100644
--- a/kernel/events/core.c
+++ b/kernel/events/core.c
@@ -403,8 +403,13 @@ static cpumask_var_t perf_online_mask;
  *   0 - disallow raw tracepoint access for unpriv
  *   1 - disallow cpu events for unpriv
  *   2 - disallow kernel profiling for unpriv
+ *   3 - disallow all unpriv perf event use
  */
+#ifdef CONFIG_SECURITY_PERF_EVENTS_RESTRICT
+int sysctl_perf_event_paranoid __read_mostly = 3;
+#else
 int sysctl_perf_event_paranoid __read_mostly = 2;
+#endif
 
 /* Minimum for 512 kiB + 1 user control page */
 int sysctl_perf_event_mlock __read_mostly = 512 + (PAGE_SIZE / 1024); /* 'free' kiB per user */
@@ -10926,6 +10931,9 @@ SYSCALL_DEFINE5(perf_event_open,
 	if (flags & ~PERF_FLAG_ALL)
 		return -EINVAL;
 
+	if (perf_paranoid_any() && !capable(CAP_SYS_ADMIN))
+		return -EACCES;
+
 	err = perf_copy_attr(attr_uptr, &attr);
 	if (err)
 		return err;
diff --git a/kernel/fork.c b/kernel/fork.c
index 9180f4416dba..a02f83b1d9b4 100644
--- a/kernel/fork.c
+++ b/kernel/fork.c
@@ -106,6 +106,11 @@
 
 #define CREATE_TRACE_POINTS
 #include <trace/events/task.h>
+#ifdef CONFIG_USER_NS
+extern int unprivileged_userns_clone;
+#else
+#define unprivileged_userns_clone 0
+#endif
 
 /*
  * Minimum number of threads to boot the kernel
@@ -1779,6 +1784,10 @@ static __latent_entropy struct task_struct *copy_process(
 	if ((clone_flags & (CLONE_NEWUSER|CLONE_FS)) == (CLONE_NEWUSER|CLONE_FS))
 		return ERR_PTR(-EINVAL);
 
+	if ((clone_flags & CLONE_NEWUSER) && !unprivileged_userns_clone)
+		if (!capable(CAP_SYS_ADMIN))
+			return ERR_PTR(-EPERM);
+
 	/*
 	 * Thread groups must share signals as well, and detached threads
 	 * can only be started up within the thread group.
@@ -2837,6 +2846,12 @@ int ksys_unshare(unsigned long unshare_flags)
 	if (unshare_flags & CLONE_NEWNS)
 		unshare_flags |= CLONE_FS;
 
+	if ((unshare_flags & CLONE_NEWUSER) && !unprivileged_userns_clone) {
+		err = -EPERM;
+		if (!capable(CAP_SYS_ADMIN))
+			goto bad_unshare_out;
+	}
+
 	err = check_unshare_flags(unshare_flags);
 	if (err)
 		goto bad_unshare_out;
diff --git a/kernel/rcu/tiny.c b/kernel/rcu/tiny.c
index 477b4eb44af5..db28cc3fd301 100644
--- a/kernel/rcu/tiny.c
+++ b/kernel/rcu/tiny.c
@@ -74,7 +74,7 @@ void rcu_sched_clock_irq(int user)
 }
 
 /* Invoke the RCU callbacks whose grace period has elapsed.  */
-static __latent_entropy void rcu_process_callbacks(struct softirq_action *unused)
+static __latent_entropy void rcu_process_callbacks(void)
 {
 	struct rcu_head *next, *list;
 	unsigned long flags;
diff --git a/kernel/rcu/tree.c b/kernel/rcu/tree.c
index 62e59596a30a..853e42ee4e54 100644
--- a/kernel/rcu/tree.c
+++ b/kernel/rcu/tree.c
@@ -2382,7 +2382,7 @@ static __latent_entropy void rcu_core(void)
 	trace_rcu_utilization(TPS("End RCU core"));
 }
 
-static void rcu_core_si(struct softirq_action *h)
+static void rcu_core_si(void)
 {
 	rcu_core();
 }
diff --git a/kernel/sched/fair.c b/kernel/sched/fair.c
index 20bf1f66733a..995f1be03e44 100644
--- a/kernel/sched/fair.c
+++ b/kernel/sched/fair.c
@@ -9931,7 +9931,7 @@ int newidle_balance(struct rq *this_rq, struct rq_flags *rf)
  * run_rebalance_domains is triggered when needed from the scheduler tick.
  * Also triggered for nohz idle balancing (with nohz_balancing_kick set).
  */
-static __latent_entropy void run_rebalance_domains(struct softirq_action *h)
+static __latent_entropy void run_rebalance_domains(void)
 {
 	struct rq *this_rq = this_rq();
 	enum cpu_idle_type idle = this_rq->idle_balance ?
diff --git a/kernel/softirq.c b/kernel/softirq.c
index 0427a86743a4..5e6a9b4ccb41 100644
--- a/kernel/softirq.c
+++ b/kernel/softirq.c
@@ -52,7 +52,7 @@ DEFINE_PER_CPU_ALIGNED(irq_cpustat_t, irq_stat);
 EXPORT_PER_CPU_SYMBOL(irq_stat);
 #endif
 
-static struct softirq_action softirq_vec[NR_SOFTIRQS] __cacheline_aligned_in_smp;
+static struct softirq_action softirq_vec[NR_SOFTIRQS] __ro_after_init __aligned(PAGE_SIZE);
 
 DEFINE_PER_CPU(struct task_struct *, ksoftirqd);
 
@@ -289,7 +289,7 @@ asmlinkage __visible void __softirq_entry __do_softirq(void)
 		kstat_incr_softirqs_this_cpu(vec_nr);
 
 		trace_softirq_entry(vec_nr);
-		h->action(h);
+		h->action();
 		trace_softirq_exit(vec_nr);
 		if (unlikely(prev_count != preempt_count())) {
 			pr_err("huh, entered softirq %u %s %p with preempt_count %08x, exited with %08x?\n",
@@ -452,7 +452,7 @@ void __raise_softirq_irqoff(unsigned int nr)
 	or_softirq_pending(1UL << nr);
 }
 
-void open_softirq(int nr, void (*action)(struct softirq_action *))
+void __init open_softirq(int nr, void (*action)(void))
 {
 	softirq_vec[nr].action = action;
 }
@@ -498,8 +498,7 @@ void __tasklet_hi_schedule(struct tasklet_struct *t)
 }
 EXPORT_SYMBOL(__tasklet_hi_schedule);
 
-static void tasklet_action_common(struct softirq_action *a,
-				  struct tasklet_head *tl_head,
+static void tasklet_action_common(struct tasklet_head *tl_head,
 				  unsigned int softirq_nr)
 {
 	struct tasklet_struct *list;
@@ -536,14 +535,14 @@ static void tasklet_action_common(struct softirq_action *a,
 	}
 }
 
-static __latent_entropy void tasklet_action(struct softirq_action *a)
+static __latent_entropy void tasklet_action(void)
 {
-	tasklet_action_common(a, this_cpu_ptr(&tasklet_vec), TASKLET_SOFTIRQ);
+	tasklet_action_common(this_cpu_ptr(&tasklet_vec), TASKLET_SOFTIRQ);
 }
 
-static __latent_entropy void tasklet_hi_action(struct softirq_action *a)
+static __latent_entropy void tasklet_hi_action(void)
 {
-	tasklet_action_common(a, this_cpu_ptr(&tasklet_hi_vec), HI_SOFTIRQ);
+	tasklet_action_common(this_cpu_ptr(&tasklet_hi_vec), HI_SOFTIRQ);
 }
 
 void tasklet_init(struct tasklet_struct *t,
diff --git a/kernel/sysctl.c b/kernel/sysctl.c
index 70665934d53e..8ea67d08b926 100644
--- a/kernel/sysctl.c
+++ b/kernel/sysctl.c
@@ -68,6 +68,7 @@
 #include <linux/bpf.h>
 #include <linux/mount.h>
 #include <linux/userfaultfd_k.h>
+#include <linux/tty.h>
 
 #include "../lib/kstrtox.h"
 
@@ -104,12 +105,19 @@
 #if defined(CONFIG_SYSCTL)
 
 /* External variables not in a header file. */
+#if IS_ENABLED(CONFIG_USB)
+int deny_new_usb __read_mostly = 0;
+EXPORT_SYMBOL(deny_new_usb);
+#endif
 extern int suid_dumpable;
 #ifdef CONFIG_COREDUMP
 extern int core_uses_pid;
 extern char core_pattern[];
 extern unsigned int core_pipe_limit;
 #endif
+#ifdef CONFIG_USER_NS
+extern int unprivileged_userns_clone;
+#endif
 extern int pid_max;
 extern int pid_max_min, pid_max_max;
 extern int percpu_pagelist_fraction;
@@ -121,32 +129,32 @@ extern int sysctl_nr_trim_pages;
 
 /* Constants used for minimum and  maximum */
 #ifdef CONFIG_LOCKUP_DETECTOR
-static int sixty = 60;
+static int sixty __read_only = 60;
 #endif
 
-static int __maybe_unused neg_one = -1;
-static int __maybe_unused two = 2;
-static int __maybe_unused four = 4;
-static unsigned long zero_ul;
-static unsigned long one_ul = 1;
-static unsigned long long_max = LONG_MAX;
-static int one_hundred = 100;
-static int one_thousand = 1000;
+static int __maybe_unused neg_one __read_only = -1;
+static int __maybe_unused two __read_only = 2;
+static int __maybe_unused four __read_only = 4;
+static unsigned long zero_ul __read_only;
+static unsigned long one_ul __read_only = 1;
+static unsigned long long_max __read_only = LONG_MAX;
+static int one_hundred __read_only = 100;
+static int one_thousand __read_only = 1000;
 #ifdef CONFIG_PRINTK
-static int ten_thousand = 10000;
+static int ten_thousand __read_only = 10000;
 #endif
 #ifdef CONFIG_PERF_EVENTS
-static int six_hundred_forty_kb = 640 * 1024;
+static int six_hundred_forty_kb __read_only = 640 * 1024;
 #endif
 
 /* this is needed for the proc_doulongvec_minmax of vm_dirty_bytes */
-static unsigned long dirty_bytes_min = 2 * PAGE_SIZE;
+static unsigned long dirty_bytes_min __read_only = 2 * PAGE_SIZE;
 
 /* this is needed for the proc_dointvec_minmax for [fs_]overflow UID and GID */
-static int maxolduid = 65535;
-static int minolduid;
+static int maxolduid __read_only = 65535;
+static int minolduid __read_only;
 
-static int ngroups_max = NGROUPS_MAX;
+static int ngroups_max __read_only = NGROUPS_MAX;
 static const int cap_last_cap = CAP_LAST_CAP;
 
 /*
@@ -154,9 +162,12 @@ static const int cap_last_cap = CAP_LAST_CAP;
  * and hung_task_check_interval_secs
  */
 #ifdef CONFIG_DETECT_HUNG_TASK
-static unsigned long hung_task_timeout_max = (LONG_MAX/HZ);
+static unsigned long hung_task_timeout_max __read_only = (LONG_MAX/HZ);
 #endif
 
+int device_sidechannel_restrict __read_mostly = 1;
+EXPORT_SYMBOL(device_sidechannel_restrict);
+
 #ifdef CONFIG_INOTIFY_USER
 #include <linux/inotify.h>
 #endif
@@ -301,19 +312,19 @@ static struct ctl_table sysctl_base_table[] = {
 };
 
 #ifdef CONFIG_SCHED_DEBUG
-static int min_sched_granularity_ns = 100000;		/* 100 usecs */
-static int max_sched_granularity_ns = NSEC_PER_SEC;	/* 1 second */
-static int min_wakeup_granularity_ns;			/* 0 usecs */
-static int max_wakeup_granularity_ns = NSEC_PER_SEC;	/* 1 second */
+static int min_sched_granularity_ns __read_only = 100000;		/* 100 usecs */
+static int max_sched_granularity_ns __read_only = NSEC_PER_SEC;	/* 1 second */
+static int min_wakeup_granularity_ns __read_only;			/* 0 usecs */
+static int max_wakeup_granularity_ns __read_only = NSEC_PER_SEC;	/* 1 second */
 #ifdef CONFIG_SMP
-static int min_sched_tunable_scaling = SCHED_TUNABLESCALING_NONE;
-static int max_sched_tunable_scaling = SCHED_TUNABLESCALING_END-1;
+static int min_sched_tunable_scaling __read_only = SCHED_TUNABLESCALING_NONE;
+static int max_sched_tunable_scaling __read_only = SCHED_TUNABLESCALING_END-1;
 #endif /* CONFIG_SMP */
 #endif /* CONFIG_SCHED_DEBUG */
 
 #ifdef CONFIG_COMPACTION
-static int min_extfrag_threshold;
-static int max_extfrag_threshold = 1000;
+static int min_extfrag_threshold __read_only;
+static int max_extfrag_threshold __read_only = 1000;
 #endif
 
 static struct ctl_table kern_table[] = {
@@ -546,6 +557,15 @@ static struct ctl_table kern_table[] = {
 		.proc_handler	= proc_dointvec,
 	},
 #endif
+#ifdef CONFIG_USER_NS
+	{
+		.procname	= "unprivileged_userns_clone",
+		.data		= &unprivileged_userns_clone,
+		.maxlen		= sizeof(int),
+		.mode		= 0644,
+		.proc_handler	= proc_dointvec,
+	},
+#endif
 #ifdef CONFIG_PROC_SYSCTL
 	{
 		.procname	= "tainted",
@@ -901,6 +921,37 @@ static struct ctl_table kern_table[] = {
 		.extra1		= SYSCTL_ZERO,
 		.extra2		= &two,
 	},
+#endif
+#if defined CONFIG_TTY
+	{
+		.procname	= "tiocsti_restrict",
+		.data		= &tiocsti_restrict,
+		.maxlen		= sizeof(int),
+		.mode		= 0644,
+		.proc_handler	= proc_dointvec_minmax_sysadmin,
+		.extra1		= SYSCTL_ZERO,
+		.extra2		= SYSCTL_ONE,
+	},
+#endif
+	{
+		.procname	= "device_sidechannel_restrict",
+		.data		= &device_sidechannel_restrict,
+		.maxlen		= sizeof(int),
+		.mode		= 0644,
+		.proc_handler	= proc_dointvec_minmax_sysadmin,
+		.extra1		= SYSCTL_ZERO,
+		.extra2		= SYSCTL_ONE,
+	},
+#if IS_ENABLED(CONFIG_USB)
+	{
+		.procname	= "deny_new_usb",
+		.data		= &deny_new_usb,
+		.maxlen		= sizeof(int),
+		.mode		= 0644,
+		.proc_handler	= proc_dointvec_minmax_sysadmin,
+		.extra1		= SYSCTL_ZERO,
+		.extra2		= SYSCTL_ONE,
+	},
 #endif
 	{
 		.procname	= "ngroups_max",
diff --git a/kernel/time/hrtimer.c b/kernel/time/hrtimer.c
index 7f31932216a1..9ede224fc81f 100644
--- a/kernel/time/hrtimer.c
+++ b/kernel/time/hrtimer.c
@@ -1583,7 +1583,7 @@ static void __hrtimer_run_queues(struct hrtimer_cpu_base *cpu_base, ktime_t now,
 	}
 }
 
-static __latent_entropy void hrtimer_run_softirq(struct softirq_action *h)
+static __latent_entropy void hrtimer_run_softirq(void)
 {
 	struct hrtimer_cpu_base *cpu_base = this_cpu_ptr(&hrtimer_bases);
 	unsigned long flags;
diff --git a/kernel/time/timer.c b/kernel/time/timer.c
index a3ae244b1bcd..a727744cf737 100644
--- a/kernel/time/timer.c
+++ b/kernel/time/timer.c
@@ -1798,7 +1798,7 @@ static inline void __run_timers(struct timer_base *base)
 /*
  * This function runs timers and the timer-tq in bottom half context.
  */
-static __latent_entropy void run_timer_softirq(struct softirq_action *h)
+static __latent_entropy void run_timer_softirq(void)
 {
 	struct timer_base *base = this_cpu_ptr(&timer_bases[BASE_STD]);
 
diff --git a/kernel/user_namespace.c b/kernel/user_namespace.c
index 8eadadc478f9..c36ecd19562c 100644
--- a/kernel/user_namespace.c
+++ b/kernel/user_namespace.c
@@ -21,6 +21,13 @@
 #include <linux/bsearch.h>
 #include <linux/sort.h>
 
+/* sysctl */
+#ifdef CONFIG_USER_NS_UNPRIVILEGED
+int unprivileged_userns_clone = 1;
+#else
+int unprivileged_userns_clone;
+#endif
+
 static struct kmem_cache *user_ns_cachep __read_mostly;
 static DEFINE_MUTEX(userns_state_mutex);
 
diff --git a/lib/Kconfig.debug b/lib/Kconfig.debug
index 6118d99117da..66197a066a49 100644
--- a/lib/Kconfig.debug
+++ b/lib/Kconfig.debug
@@ -343,6 +343,9 @@ config SECTION_MISMATCH_WARN_ONLY
 
 	  If unsure, say Y.
 
+config DEBUG_WRITABLE_FUNCTION_POINTERS_VERBOSE
+	bool "Enable verbose reporting of writable function pointers"
+
 #
 # Select this config option from the architecture Kconfig, if it
 # is preferred to always offer frame pointers as a config
@@ -965,6 +968,7 @@ endmenu # "Debug lockups and hangs"
 
 config PANIC_ON_OOPS
 	bool "Panic on Oops"
+	default y
 	help
 	  Say Y here to enable the kernel to panic when it oopses. This
 	  has the same effect as setting oops=panic on the kernel command
@@ -974,7 +978,7 @@ config PANIC_ON_OOPS
 	  anything erroneous after an oops which could result in data
 	  corruption or other issues.
 
-	  Say N if unsure.
+	  Say Y if unsure.
 
 config PANIC_ON_OOPS_VALUE
 	int
@@ -1343,6 +1347,7 @@ config DEBUG_BUGVERBOSE
 config DEBUG_LIST
 	bool "Debug linked list manipulation"
 	depends on DEBUG_KERNEL || BUG_ON_DATA_CORRUPTION
+	default y
 	help
 	  Enable this to turn on extended checks in the linked-list
 	  walking routines.
@@ -2064,6 +2069,7 @@ config MEMTEST
 config BUG_ON_DATA_CORRUPTION
 	bool "Trigger a BUG when data corruption is detected"
 	select DEBUG_LIST
+	default y
 	help
 	  Select this option if the kernel should BUG when it encounters
 	  data corruption in kernel memory structures when they get checked
@@ -2103,6 +2109,7 @@ config STRICT_DEVMEM
 config IO_STRICT_DEVMEM
 	bool "Filter I/O access to /dev/mem"
 	depends on STRICT_DEVMEM
+	default y
 	---help---
 	  If this option is disabled, you allow userspace (root) access to all
 	  io-memory regardless of whether a driver is actively using that
diff --git a/lib/irq_poll.c b/lib/irq_poll.c
index 2f17b488d58e..b6e7996a0058 100644
--- a/lib/irq_poll.c
+++ b/lib/irq_poll.c
@@ -75,7 +75,7 @@ void irq_poll_complete(struct irq_poll *iop)
 }
 EXPORT_SYMBOL(irq_poll_complete);
 
-static void __latent_entropy irq_poll_softirq(struct softirq_action *h)
+static void __latent_entropy irq_poll_softirq(void)
 {
 	struct list_head *list = this_cpu_ptr(&blk_cpu_iopoll);
 	int rearm = 0, budget = irq_poll_budget;
diff --git a/lib/kobject.c b/lib/kobject.c
index 386873bdd51c..e803cb6ce69e 100644
--- a/lib/kobject.c
+++ b/lib/kobject.c
@@ -1022,9 +1022,9 @@ EXPORT_SYMBOL_GPL(kset_create_and_add);
 
 
 static DEFINE_SPINLOCK(kobj_ns_type_lock);
-static const struct kobj_ns_type_operations *kobj_ns_ops_tbl[KOBJ_NS_TYPES];
+static const struct kobj_ns_type_operations *kobj_ns_ops_tbl[KOBJ_NS_TYPES] __ro_after_init;
 
-int kobj_ns_type_register(const struct kobj_ns_type_operations *ops)
+int __init kobj_ns_type_register(const struct kobj_ns_type_operations *ops)
 {
 	enum kobj_ns_type type = ops->type;
 	int error;
diff --git a/lib/nlattr.c b/lib/nlattr.c
index cace9b307781..39ba1387045d 100644
--- a/lib/nlattr.c
+++ b/lib/nlattr.c
@@ -571,6 +571,8 @@ int nla_memcpy(void *dest, const struct nlattr *src, int count)
 {
 	int minlen = min_t(int, count, nla_len(src));
 
+	BUG_ON(minlen < 0);
+
 	memcpy(dest, nla_data(src), minlen);
 	if (count > minlen)
 		memset(dest + minlen, 0, count - minlen);
diff --git a/lib/vsprintf.c b/lib/vsprintf.c
index fb4af73142b4..4479c5ffe4a8 100644
--- a/lib/vsprintf.c
+++ b/lib/vsprintf.c
@@ -778,7 +778,7 @@ static char *ptr_to_id(char *buf, char *end, const void *ptr,
 	return pointer_string(buf, end, (const void *)hashval, spec);
 }
 
-int kptr_restrict __read_mostly;
+int kptr_restrict __read_mostly = 2;
 
 static noinline_for_stack
 char *restricted_pointer(char *buf, char *end, const void *ptr,
diff --git a/mm/Kconfig b/mm/Kconfig
index a5dae9a7eb51..0a3070c5a125 100644
--- a/mm/Kconfig
+++ b/mm/Kconfig
@@ -303,7 +303,8 @@ config KSM
 config DEFAULT_MMAP_MIN_ADDR
         int "Low address space to protect from user allocation"
 	depends on MMU
-        default 4096
+	default 32768 if ARM || (ARM64 && COMPAT)
+	default 65536
         help
 	  This is the portion of low virtual memory which should be protected
 	  from userspace allocation.  Keeping a user from writing to low pages
diff --git a/mm/mmap.c b/mm/mmap.c
index a3584a90c55c..2208e718d3e9 100644
--- a/mm/mmap.c
+++ b/mm/mmap.c
@@ -228,6 +228,13 @@ SYSCALL_DEFINE1(brk, unsigned long, brk)
 
 	newbrk = PAGE_ALIGN(brk);
 	oldbrk = PAGE_ALIGN(mm->brk);
+	/* properly handle unaligned min_brk as an empty heap */
+	if (min_brk & ~PAGE_MASK) {
+		if (brk == min_brk)
+			newbrk -= PAGE_SIZE;
+		if (mm->brk == min_brk)
+			oldbrk -= PAGE_SIZE;
+	}
 	if (oldbrk == newbrk) {
 		mm->brk = brk;
 		goto success;
diff --git a/mm/page_alloc.c b/mm/page_alloc.c
index 67a9943aa595..cdac6a9162be 100644
--- a/mm/page_alloc.c
+++ b/mm/page_alloc.c
@@ -68,6 +68,7 @@
 #include <linux/lockdep.h>
 #include <linux/nmi.h>
 #include <linux/psi.h>
+#include <linux/random.h>
 
 #include <asm/sections.h>
 #include <asm/tlbflush.h>
@@ -106,6 +107,15 @@ struct pcpu_drain {
 DEFINE_MUTEX(pcpu_drain_mutex);
 DEFINE_PER_CPU(struct pcpu_drain, pcpu_drain);
 
+bool __meminitdata extra_latent_entropy;
+
+static int __init setup_extra_latent_entropy(char *str)
+{
+	extra_latent_entropy = true;
+	return 0;
+}
+early_param("extra_latent_entropy", setup_extra_latent_entropy);
+
 #ifdef CONFIG_GCC_PLUGIN_LATENT_ENTROPY
 volatile unsigned long latent_entropy __latent_entropy;
 EXPORT_SYMBOL(latent_entropy);
@@ -1432,6 +1442,25 @@ static void __free_pages_ok(struct page *page, unsigned int order)
 	local_irq_restore(flags);
 }
 
+static void __init __gather_extra_latent_entropy(struct page *page,
+						 unsigned int nr_pages)
+{
+	if (extra_latent_entropy && !PageHighMem(page) && page_to_pfn(page) < 0x100000) {
+		unsigned long hash = 0;
+		size_t index, end = PAGE_SIZE * nr_pages / sizeof hash;
+		const unsigned long *data = lowmem_page_address(page);
+
+		for (index = 0; index < end; index++)
+			hash ^= hash + data[index];
+#ifdef CONFIG_GCC_PLUGIN_LATENT_ENTROPY
+		latent_entropy ^= hash;
+		add_device_randomness((const void *)&latent_entropy, sizeof(latent_entropy));
+#else
+		add_device_randomness((const void *)&hash, sizeof(hash));
+#endif
+	}
+}
+
 void __free_pages_core(struct page *page, unsigned int order)
 {
 	unsigned int nr_pages = 1 << order;
@@ -1446,7 +1475,6 @@ void __free_pages_core(struct page *page, unsigned int order)
 	}
 	__ClearPageReserved(p);
 	set_page_count(p, 0);
-
 	atomic_long_add(nr_pages, &page_zone(page)->managed_pages);
 	set_page_refcounted(page);
 	__free_pages(page, order);
@@ -1497,6 +1525,7 @@ void __init memblock_free_pages(struct page *page, unsigned long pfn,
 {
 	if (early_page_uninitialised(pfn))
 		return;
+	__gather_extra_latent_entropy(page, 1 << order);
 	__free_pages_core(page, order);
 }
 
@@ -1588,6 +1617,7 @@ static void __init deferred_free_range(unsigned long pfn,
 	if (nr_pages == pageblock_nr_pages &&
 	    (pfn & (pageblock_nr_pages - 1)) == 0) {
 		set_pageblock_migratetype(page, MIGRATE_MOVABLE);
+		__gather_extra_latent_entropy(page, 1 << pageblock_order);
 		__free_pages_core(page, pageblock_order);
 		return;
 	}
@@ -1595,6 +1625,7 @@ static void __init deferred_free_range(unsigned long pfn,
 	for (i = 0; i < nr_pages; i++, page++, pfn++) {
 		if ((pfn & (pageblock_nr_pages - 1)) == 0)
 			set_pageblock_migratetype(page, MIGRATE_MOVABLE);
+		__gather_extra_latent_entropy(page, 1);
 		__free_pages_core(page, 0);
 	}
 }
@@ -2157,6 +2188,12 @@ static void prep_new_page(struct page *page, unsigned int order, gfp_t gfp_flags
 {
 	post_alloc_hook(page, order, gfp_flags);
 
+	if (IS_ENABLED(CONFIG_PAGE_SANITIZE_VERIFY) && want_init_on_free()) {
+		int i;
+		for (i = 0; i < (1 << order); i++)
+			verify_zero_highpage(page + i);
+	}
+
 	if (!free_pages_prezeroed() && want_init_on_alloc(gfp_flags))
 		kernel_init_free_pages(page, 1 << order);
 
diff --git a/mm/slab.h b/mm/slab.h
index b2b01694dc43..b531661095a2 100644
--- a/mm/slab.h
+++ b/mm/slab.h
@@ -470,9 +470,13 @@ static inline struct kmem_cache *virt_to_cache(const void *obj)
 	struct page *page;
 
 	page = virt_to_head_page(obj);
+#ifdef CONFIG_BUG_ON_DATA_CORRUPTION
+	BUG_ON(!PageSlab(page));
+#else
 	if (WARN_ONCE(!PageSlab(page), "%s: Object is not a Slab page!\n",
 					__func__))
 		return NULL;
+#endif
 	return page->slab_cache;
 }
 
@@ -518,9 +522,14 @@ static inline struct kmem_cache *cache_from_obj(struct kmem_cache *s, void *x)
 		return s;
 
 	cachep = virt_to_cache(x);
-	WARN_ONCE(cachep && !slab_equal_or_root(cachep, s),
-		  "%s: Wrong slab cache. %s but object is from %s\n",
-		  __func__, s->name, cachep->name);
+	if (cachep && !slab_equal_or_root(cachep, s)) {
+#ifdef CONFIG_BUG_ON_DATA_CORRUPTION
+		BUG();
+#else
+		WARN_ONCE(1, "%s: Wrong slab cache. %s but object is from %s\n",
+			     __func__, s->name, cachep->name);
+#endif
+	}
 	return cachep;
 }
 
@@ -545,7 +554,7 @@ static inline size_t slab_ksize(const struct kmem_cache *s)
 	 * back there or track user information then we can
 	 * only use the space before that information.
 	 */
-	if (s->flags & (SLAB_TYPESAFE_BY_RCU | SLAB_STORE_USER))
+	if ((s->flags & (SLAB_TYPESAFE_BY_RCU | SLAB_STORE_USER)) || IS_ENABLED(CONFIG_SLAB_CANARY))
 		return s->inuse;
 	/*
 	 * Else we can use all the padding etc for the allocation
@@ -674,8 +683,10 @@ static inline void cache_random_seq_destroy(struct kmem_cache *cachep) { }
 static inline bool slab_want_init_on_alloc(gfp_t flags, struct kmem_cache *c)
 {
 	if (static_branch_unlikely(&init_on_alloc)) {
+#ifndef CONFIG_SLUB
 		if (c->ctor)
 			return false;
+#endif
 		if (c->flags & (SLAB_TYPESAFE_BY_RCU | SLAB_POISON))
 			return flags & __GFP_ZERO;
 		return true;
@@ -685,9 +696,15 @@ static inline bool slab_want_init_on_alloc(gfp_t flags, struct kmem_cache *c)
 
 static inline bool slab_want_init_on_free(struct kmem_cache *c)
 {
-	if (static_branch_unlikely(&init_on_free))
-		return !(c->ctor ||
-			 (c->flags & (SLAB_TYPESAFE_BY_RCU | SLAB_POISON)));
+	if (static_branch_unlikely(&init_on_free)) {
+#ifndef CONFIG_SLUB
+		if (c->ctor)
+			return false;
+#endif
+		if (c->flags & (SLAB_TYPESAFE_BY_RCU | SLAB_POISON))
+			return false;
+		return true;
+	}
 	return false;
 }
 
diff --git a/mm/slab_common.c b/mm/slab_common.c
index e36dd36c7076..94cb3eed189c 100644
--- a/mm/slab_common.c
+++ b/mm/slab_common.c
@@ -28,10 +28,10 @@
 
 #include "slab.h"
 
-enum slab_state slab_state;
+enum slab_state slab_state __ro_after_init;
 LIST_HEAD(slab_caches);
 DEFINE_MUTEX(slab_mutex);
-struct kmem_cache *kmem_cache;
+struct kmem_cache *kmem_cache __ro_after_init;
 
 #ifdef CONFIG_HARDENED_USERCOPY
 bool usercopy_fallback __ro_after_init =
@@ -59,7 +59,7 @@ static DECLARE_WORK(slab_caches_to_rcu_destroy_work,
 /*
  * Merge control. If this is set then no merging of slab caches will occur.
  */
-static bool slab_nomerge = !IS_ENABLED(CONFIG_SLAB_MERGE_DEFAULT);
+static bool slab_nomerge __ro_after_init = !IS_ENABLED(CONFIG_SLAB_MERGE_DEFAULT);
 
 static int __init setup_slab_nomerge(char *str)
 {
diff --git a/mm/slub.c b/mm/slub.c
index 822ba0724529..0f390295b4df 100644
--- a/mm/slub.c
+++ b/mm/slub.c
@@ -125,6 +125,12 @@ static inline int kmem_cache_debug(struct kmem_cache *s)
 #endif
 }
 
+static inline bool has_sanitize_verify(struct kmem_cache *s)
+{
+	return IS_ENABLED(CONFIG_SLAB_SANITIZE_VERIFY) &&
+	       slab_want_init_on_free(s);
+}
+
 void *fixup_red_left(struct kmem_cache *s, void *p)
 {
 	if (kmem_cache_debug(s) && s->flags & SLAB_RED_ZONE)
@@ -309,6 +315,35 @@ static inline void set_freepointer(struct kmem_cache *s, void *object, void *fp)
 	*(void **)freeptr_addr = freelist_ptr(s, fp, freeptr_addr);
 }
 
+#ifdef CONFIG_SLAB_CANARY
+static inline unsigned long *get_canary(struct kmem_cache *s, void *object)
+{
+	if (s->offset)
+		return object + s->offset + sizeof(void *);
+	return object + s->inuse;
+}
+
+static inline unsigned long get_canary_value(const void *canary, unsigned long value)
+{
+	return (value ^ (unsigned long)canary) & CANARY_MASK;
+}
+
+static inline void set_canary(struct kmem_cache *s, void *object, unsigned long value)
+{
+	unsigned long *canary = get_canary(s, object);
+	*canary = get_canary_value(canary, value);
+}
+
+static inline void check_canary(struct kmem_cache *s, void *object, unsigned long value)
+{
+	unsigned long *canary = get_canary(s, object);
+	BUG_ON(*canary != get_canary_value(canary, value));
+}
+#else
+#define set_canary(s, object, value)
+#define check_canary(s, object, value)
+#endif
+
 /* Loop over all objects in a slab */
 #define for_each_object(__p, __s, __addr, __objects) \
 	for (__p = fixup_red_left(__s, __addr); \
@@ -476,13 +511,13 @@ static inline void *restore_red_left(struct kmem_cache *s, void *p)
  * Debug settings:
  */
 #if defined(CONFIG_SLUB_DEBUG_ON)
-static slab_flags_t slub_debug = DEBUG_DEFAULT_FLAGS;
+static slab_flags_t slub_debug __ro_after_init = DEBUG_DEFAULT_FLAGS;
 #else
-static slab_flags_t slub_debug;
+static slab_flags_t slub_debug __ro_after_init;
 #endif
 
-static char *slub_debug_slabs;
-static int disable_higher_order_debug;
+static char *slub_debug_slabs __ro_after_init;
+static int disable_higher_order_debug __ro_after_init;
 
 /*
  * slub is about to manipulate internal object metadata.  This memory lies
@@ -543,6 +578,9 @@ static struct track *get_track(struct kmem_cache *s, void *object,
 	else
 		p = object + s->inuse;
 
+	if (IS_ENABLED(CONFIG_SLAB_CANARY))
+		p = (void *)p + sizeof(void *);
+
 	return p + alloc;
 }
 
@@ -687,6 +725,9 @@ static void print_trailer(struct kmem_cache *s, struct page *page, u8 *p)
 	else
 		off = s->inuse;
 
+	if (IS_ENABLED(CONFIG_SLAB_CANARY))
+		off += sizeof(void *);
+
 	if (s->flags & SLAB_STORE_USER)
 		off += 2 * sizeof(struct track);
 
@@ -816,6 +857,9 @@ static int check_pad_bytes(struct kmem_cache *s, struct page *page, u8 *p)
 		/* Freepointer is placed after the object. */
 		off += sizeof(void *);
 
+	if (IS_ENABLED(CONFIG_SLAB_CANARY))
+		off += sizeof(void *);
+
 	if (s->flags & SLAB_STORE_USER)
 		/* We also have user information there */
 		off += 2 * sizeof(struct track);
@@ -1460,6 +1504,8 @@ static inline bool slab_free_freelist_hook(struct kmem_cache *s,
 		object = next;
 		next = get_freepointer(s, object);
 
+		check_canary(s, object, s->random_active);
+
 		if (slab_want_init_on_free(s)) {
 			/*
 			 * Clear the object and the metadata, but don't touch
@@ -1470,8 +1516,12 @@ static inline bool slab_free_freelist_hook(struct kmem_cache *s,
 							   : 0;
 			memset((char *)object + s->inuse, 0,
 			       s->size - s->inuse - rsize);
-
+			if (!IS_ENABLED(CONFIG_SLAB_SANITIZE_VERIFY) && s->ctor)
+				s->ctor(object);
 		}
+
+		set_canary(s, object, s->random_inactive);
+
 		/* If object's reuse doesn't have to be delayed */
 		if (!slab_free_hook(s, object)) {
 			/* Move object to the new freelist */
@@ -1479,6 +1529,17 @@ static inline bool slab_free_freelist_hook(struct kmem_cache *s,
 			*head = object;
 			if (!*tail)
 				*tail = object;
+		} else if (slab_want_init_on_free(s) && s->ctor) {
+			/* Objects that are put into quarantine by KASAN will
+			 * still undergo free_consistency_checks() and thus
+			 * need to show a valid freepointer to check_object().
+			 *
+			 * Note that doing this for all caches (not just ctor
+			 * ones, which have s->offset != NULL)) causes a GPF,
+			 * due to KASAN poisoning and the way set_freepointer()
+			 * eventually dereferences the freepointer.
+			 */
+			set_freepointer(s, object, NULL);
 		}
 	} while (object != old_tail);
 
@@ -1492,8 +1553,9 @@ static void *setup_object(struct kmem_cache *s, struct page *page,
 				void *object)
 {
 	setup_object_debug(s, page, object);
+	set_canary(s, object, s->random_inactive);
 	object = kasan_init_slab_obj(s, object);
-	if (unlikely(s->ctor)) {
+	if (unlikely(s->ctor) && !has_sanitize_verify(s)) {
 		kasan_unpoison_object_data(s, object);
 		s->ctor(object);
 		kasan_poison_object_data(s, object);
@@ -2787,8 +2849,28 @@ static __always_inline void *slab_alloc_node(struct kmem_cache *s,
 
 	maybe_wipe_obj_freeptr(s, object);
 
-	if (unlikely(slab_want_init_on_alloc(gfpflags, s)) && object)
+	if (has_sanitize_verify(s) && object) {
+		/* KASAN hasn't unpoisoned the object yet (this is done in the
+		 * post-alloc hook), so let's do it temporarily.
+		 */
+		kasan_unpoison_object_data(s, object);
+		BUG_ON(memchr_inv(object, 0, s->object_size));
+		if (s->ctor)
+			s->ctor(object);
+		kasan_poison_object_data(s, object);
+	} else if (unlikely(slab_want_init_on_alloc(gfpflags, s)) && object) {
 		memset(object, 0, s->object_size);
+		if (s->ctor) {
+			kasan_unpoison_object_data(s, object);
+			s->ctor(object);
+			kasan_poison_object_data(s, object);
+		}
+	}
+
+	if (object) {
+		check_canary(s, object, s->random_inactive);
+		set_canary(s, object, s->random_active);
+	}
 
 	slab_post_alloc_hook(s, gfpflags, 1, &object);
 
@@ -3173,7 +3255,7 @@ int kmem_cache_alloc_bulk(struct kmem_cache *s, gfp_t flags, size_t size,
 			  void **p)
 {
 	struct kmem_cache_cpu *c;
-	int i;
+	int i, k;
 
 	/* memcg and kmem_cache debug support */
 	s = slab_pre_alloc_hook(s, flags);
@@ -3222,11 +3304,35 @@ int kmem_cache_alloc_bulk(struct kmem_cache *s, gfp_t flags, size_t size,
 	local_irq_enable();
 
 	/* Clear memory outside IRQ disabled fastpath loop */
-	if (unlikely(slab_want_init_on_alloc(flags, s))) {
+	if (has_sanitize_verify(s)) {
 		int j;
 
-		for (j = 0; j < i; j++)
+		for (j = 0; j < i; j++) {
+			/* KASAN hasn't unpoisoned the object yet (this is done
+			 * in the post-alloc hook), so let's do it temporarily.
+			 */
+			kasan_unpoison_object_data(s, p[j]);
+			BUG_ON(memchr_inv(p[j], 0, s->object_size));
+			if (s->ctor)
+				s->ctor(p[j]);
+			kasan_poison_object_data(s, p[j]);
+		}
+	} else if (unlikely(slab_want_init_on_alloc(flags, s))) {
+		int j;
+
+		for (j = 0; j < i; j++) {
 			memset(p[j], 0, s->object_size);
+			if (s->ctor) {
+				kasan_unpoison_object_data(s, p[j]);
+				s->ctor(p[j]);
+				kasan_poison_object_data(s, p[j]);
+			}
+		}
+	}
+
+	for (k = 0; k < i; k++) {
+		check_canary(s, p[k], s->random_inactive);
+		set_canary(s, p[k], s->random_active);
 	}
 
 	/* memcg and kmem_cache debug support */
@@ -3260,9 +3366,9 @@ EXPORT_SYMBOL(kmem_cache_alloc_bulk);
  * and increases the number of allocations possible without having to
  * take the list_lock.
  */
-static unsigned int slub_min_order;
-static unsigned int slub_max_order = PAGE_ALLOC_COSTLY_ORDER;
-static unsigned int slub_min_objects;
+static unsigned int slub_min_order __ro_after_init;
+static unsigned int slub_max_order __ro_after_init = PAGE_ALLOC_COSTLY_ORDER;
+static unsigned int slub_min_objects __ro_after_init;
 
 /*
  * Calculate the order of allocation given an slab object size.
@@ -3430,6 +3536,7 @@ static void early_kmem_cache_node_alloc(int node)
 	init_object(kmem_cache_node, n, SLUB_RED_ACTIVE);
 	init_tracking(kmem_cache_node, n);
 #endif
+	set_canary(kmem_cache_node, n, kmem_cache_node->random_active);
 	n = kasan_kmalloc(kmem_cache_node, n, sizeof(struct kmem_cache_node),
 		      GFP_KERNEL);
 	page->freelist = get_freepointer(kmem_cache_node, n);
@@ -3590,6 +3697,9 @@ static int calculate_sizes(struct kmem_cache *s, int forced_order)
 		size += sizeof(void *);
 	}
 
+	if (IS_ENABLED(CONFIG_SLAB_CANARY))
+		size += sizeof(void *);
+
 #ifdef CONFIG_SLUB_DEBUG
 	if (flags & SLAB_STORE_USER)
 		/*
@@ -3662,6 +3772,10 @@ static int kmem_cache_open(struct kmem_cache *s, slab_flags_t flags)
 #ifdef CONFIG_SLAB_FREELIST_HARDENED
 	s->random = get_random_long();
 #endif
+#ifdef CONFIG_SLAB_CANARY
+	s->random_active = get_random_long();
+	s->random_inactive = get_random_long();
+#endif
 
 	if (!calculate_sizes(s, -1))
 		goto error;
@@ -3937,6 +4051,8 @@ void __check_heap_object(const void *ptr, unsigned long n, struct page *page,
 		offset -= s->red_left_pad;
 	}
 
+	check_canary(s, (void *)ptr - offset, s->random_active);
+
 	/* Allow address range falling entirely within usercopy region. */
 	if (offset >= s->useroffset &&
 	    offset - s->useroffset <= s->usersize &&
@@ -3970,7 +4086,11 @@ size_t __ksize(const void *object)
 	page = virt_to_head_page(object);
 
 	if (unlikely(!PageSlab(page))) {
+#ifdef CONFIG_BUG_ON_DATA_CORRUPTION
+		BUG_ON(!PageCompound(page));
+#else
 		WARN_ON(!PageCompound(page));
+#endif
 		return page_size(page);
 	}
 
@@ -4815,7 +4935,7 @@ enum slab_stat_type {
 #define SO_TOTAL	(1 << SL_TOTAL)
 
 #ifdef CONFIG_MEMCG
-static bool memcg_sysfs_enabled = IS_ENABLED(CONFIG_SLUB_MEMCG_SYSFS_ON);
+static bool memcg_sysfs_enabled __ro_after_init = IS_ENABLED(CONFIG_SLUB_MEMCG_SYSFS_ON);
 
 static int __init setup_slub_memcg_sysfs(char *str)
 {
diff --git a/mm/swap.c b/mm/swap.c
index 38c3fa4308e2..0534c2e348c2 100644
--- a/mm/swap.c
+++ b/mm/swap.c
@@ -94,6 +94,13 @@ static void __put_compound_page(struct page *page)
 	if (!PageHuge(page))
 		__page_cache_release(page);
 	dtor = get_compound_page_dtor(page);
+	if (!PageHuge(page))
+		BUG_ON(dtor != free_compound_page
+#ifdef CONFIG_TRANSPARENT_HUGEPAGE
+			&& dtor != free_transhuge_page
+#endif
+		);
+
 	(*dtor)(page);
 }
 
diff --git a/mm/util.c b/mm/util.c
index ab358c64bbd3..afb474c171f7 100644
--- a/mm/util.c
+++ b/mm/util.c
@@ -325,9 +325,9 @@ unsigned long arch_randomize_brk(struct mm_struct *mm)
 {
 	/* Is the current task 32bit ? */
 	if (!IS_ENABLED(CONFIG_64BIT) || is_compat_task())
-		return randomize_page(mm->brk, SZ_32M);
+		return mm->brk + get_random_long() % SZ_32M + PAGE_SIZE;
 
-	return randomize_page(mm->brk, SZ_1G);
+	return mm->brk + get_random_long() % SZ_1G + PAGE_SIZE;
 }
 
 unsigned long arch_mmap_rnd(void)
diff --git a/net/core/dev.c b/net/core/dev.c
index cdc1c3a144e1..7bc55756731f 100644
--- a/net/core/dev.c
+++ b/net/core/dev.c
@@ -4474,7 +4474,7 @@ int netif_rx_ni(struct sk_buff *skb)
 }
 EXPORT_SYMBOL(netif_rx_ni);
 
-static __latent_entropy void net_tx_action(struct softirq_action *h)
+static __latent_entropy void net_tx_action(void)
 {
 	struct softnet_data *sd = this_cpu_ptr(&softnet_data);
 
@@ -6349,7 +6349,7 @@ static int napi_poll(struct napi_struct *n, struct list_head *repoll)
 	return work;
 }
 
-static __latent_entropy void net_rx_action(struct softirq_action *h)
+static __latent_entropy void net_rx_action(void)
 {
 	struct softnet_data *sd = this_cpu_ptr(&softnet_data);
 	unsigned long time_limit = jiffies +
diff --git a/net/ipv4/Kconfig b/net/ipv4/Kconfig
index a926de2e42b5..74b44d63f1ff 100644
--- a/net/ipv4/Kconfig
+++ b/net/ipv4/Kconfig
@@ -267,6 +267,7 @@ config IP_PIMSM_V2
 
 config SYN_COOKIES
 	bool "IP: TCP syncookie support"
+	default y
 	---help---
 	  Normal TCP/IP networking is open to an attack known as "SYN
 	  flooding". This denial-of-service attack prevents legitimate remote
@@ -728,3 +729,26 @@ config TCP_MD5SIG
 	  on the Internet.
 
 	  If unsure, say N.
+
+config TCP_SIMULT_CONNECT_DEFAULT_ON
+	bool "Enable TCP simultaneous connect"
+	help
+	  Enable TCP simultaneous connect that adds a weakness in Linux's strict
+	  implementation of TCP that allows two clients to connect to each other
+	  without either entering a listening state. The weakness allows an
+	  attacker to easily prevent a client from connecting to a known server
+	  provided the source port for the connection is guessed correctly.
+
+	  As the weakness could be used to prevent an antivirus or IPS from
+	  fetching updates, or prevent an SSL gateway from fetching a CRL, it
+	  should be eliminated by disabling this option. Though Linux is one of
+	  few operating systems supporting simultaneous connect, it has no
+	  legitimate use in practice and is rarely supported by firewalls.
+
+	  Disabling this may break TCP STUNT which is used by some applications
+	  for NAT traversal.
+
+	  This setting can be overridden at runtime via the
+	  net.ipv4.tcp_simult_connect sysctl.
+
+	  If unsure, say N.
diff --git a/net/ipv4/sysctl_net_ipv4.c b/net/ipv4/sysctl_net_ipv4.c
index c83a5d05aeaa..51f464d6747a 100644
--- a/net/ipv4/sysctl_net_ipv4.c
+++ b/net/ipv4/sysctl_net_ipv4.c
@@ -604,6 +604,15 @@ static struct ctl_table ipv4_table[] = {
 		.mode		= 0644,
 		.proc_handler	= proc_do_static_key,
 	},
+	{
+		.procname	= "tcp_simult_connect",
+		.data		= &sysctl_tcp_simult_connect,
+		.maxlen		= sizeof(int),
+		.mode		= 0644,
+		.proc_handler	= proc_dointvec_minmax,
+		.extra1		= SYSCTL_ZERO,
+		.extra2		= SYSCTL_ONE,
+	},
 	{ }
 };
 
diff --git a/net/ipv4/tcp_input.c b/net/ipv4/tcp_input.c
index ab5358281000..e2fcf7190d38 100644
--- a/net/ipv4/tcp_input.c
+++ b/net/ipv4/tcp_input.c
@@ -81,6 +81,7 @@
 #include <net/busy_poll.h>
 
 int sysctl_tcp_max_orphans __read_mostly = NR_FILE;
+int sysctl_tcp_simult_connect __read_mostly = IS_ENABLED(CONFIG_TCP_SIMULT_CONNECT_DEFAULT_ON);
 
 #define FLAG_DATA		0x01 /* Incoming frame contained data.		*/
 #define FLAG_WIN_UPDATE		0x02 /* Incoming ACK was a window update.	*/
@@ -6048,7 +6049,7 @@ static int tcp_rcv_synsent_state_process(struct sock *sk, struct sk_buff *skb,
 	    tcp_paws_reject(&tp->rx_opt, 0))
 		goto discard_and_undo;
 
-	if (th->syn) {
+	if (th->syn && sysctl_tcp_simult_connect) {
 		/* We see SYN without ACK. It is attempt of
 		 * simultaneous connect with crossed SYNs.
 		 * Particularly, it can be connect to self.
diff --git a/scripts/Makefile.modpost b/scripts/Makefile.modpost
index 952fff485546..59ffccdb1be4 100644
--- a/scripts/Makefile.modpost
+++ b/scripts/Makefile.modpost
@@ -54,6 +54,7 @@ MODPOST = scripts/mod/modpost						\
 	$(if $(KBUILD_EXTMOD),$(addprefix -e ,$(KBUILD_EXTRA_SYMBOLS)))	\
 	$(if $(KBUILD_EXTMOD),-o $(modulesymfile))			\
 	$(if $(CONFIG_SECTION_MISMATCH_WARN_ONLY),,-E)			\
+	$(if $(CONFIG_DEBUG_WRITABLE_FUNCTION_POINTERS_VERBOSE),-f)	\
 	$(if $(KBUILD_MODPOST_WARN),-w)					\
 	$(if $(filter nsdeps,$(MAKECMDGOALS)),-d)
 
diff --git a/scripts/gcc-plugins/Kconfig b/scripts/gcc-plugins/Kconfig
index e3569543bdac..55cc439b3bc6 100644
--- a/scripts/gcc-plugins/Kconfig
+++ b/scripts/gcc-plugins/Kconfig
@@ -61,6 +61,11 @@ config GCC_PLUGIN_LATENT_ENTROPY
 	  is some slowdown of the boot process (about 0.5%) and fork and
 	  irq processing.
 
+	  When extra_latent_entropy is passed on the kernel command line,
+	  entropy will be extracted from up to the first 4GB of RAM while the
+	  runtime memory allocator is being initialized.  This costs even more
+	  slowdown of the boot process.
+
 	  Note that entropy extracted this way is not cryptographically
 	  secure!
 
diff --git a/scripts/mod/modpost.c b/scripts/mod/modpost.c
index 52f1152c9838..74a88a1b6dc0 100644
--- a/scripts/mod/modpost.c
+++ b/scripts/mod/modpost.c
@@ -36,6 +36,8 @@ static int warn_unresolved = 0;
 /* How a symbol is exported */
 static int sec_mismatch_count = 0;
 static int sec_mismatch_fatal = 0;
+static int writable_fptr_count = 0;
+static int writable_fptr_verbose = 0;
 /* ignore missing files */
 static int ignore_missing_files;
 /* write namespace dependencies */
@@ -1019,6 +1021,7 @@ enum mismatch {
 	ANY_EXIT_TO_ANY_INIT,
 	EXPORT_TO_INIT_EXIT,
 	EXTABLE_TO_NON_TEXT,
+	DATA_TO_TEXT
 };
 
 /**
@@ -1145,6 +1148,12 @@ static const struct sectioncheck sectioncheck[] = {
 	.good_tosec = {ALL_TEXT_SECTIONS , NULL},
 	.mismatch = EXTABLE_TO_NON_TEXT,
 	.handler = extable_mismatch_handler,
+},
+/* Do not reference code from writable data */
+{
+	.fromsec = { DATA_SECTIONS, NULL },
+	.bad_tosec = { ALL_TEXT_SECTIONS, NULL },
+	.mismatch = DATA_TO_TEXT
 }
 };
 
@@ -1332,10 +1341,10 @@ static Elf_Sym *find_elf_symbol(struct elf_info *elf, Elf64_Sword addr,
 			continue;
 		if (!is_valid_name(elf, sym))
 			continue;
-		if (sym->st_value == addr)
-			return sym;
 		/* Find a symbol nearby - addr are maybe negative */
 		d = sym->st_value - addr;
+		if (d == 0)
+			return sym;
 		if (d < 0)
 			d = addr - sym->st_value;
 		if (d < distance) {
@@ -1470,7 +1479,13 @@ static void report_sec_mismatch(const char *modname,
 	char *prl_from;
 	char *prl_to;
 
-	sec_mismatch_count++;
+	if (mismatch->mismatch == DATA_TO_TEXT) {
+		writable_fptr_count++;
+		if (!writable_fptr_verbose)
+			return;
+	} else {
+		sec_mismatch_count++;
+	}
 
 	get_pretty_name(from_is_func, &from, &from_p);
 	get_pretty_name(to_is_func, &to, &to_p);
@@ -1592,6 +1607,12 @@ static void report_sec_mismatch(const char *modname,
 		fatal("There's a special handler for this mismatch type, "
 		      "we should never get here.");
 		break;
+	case DATA_TO_TEXT:
+		fprintf(stderr,
+		"The %s %s:%s references\n"
+		"the %s %s:%s%s\n",
+		from, fromsec, fromsym, to, tosec, tosym, to_p);
+		break;
 	}
 	fprintf(stderr, "\n");
 }
@@ -2569,7 +2590,7 @@ int main(int argc, char **argv)
 	struct ext_sym_list *extsym_iter;
 	struct ext_sym_list *extsym_start = NULL;
 
-	while ((opt = getopt(argc, argv, "i:I:e:mnsT:o:awEd")) != -1) {
+	while ((opt = getopt(argc, argv, "i:I:e:fmnsT:o:awEd")) != -1) {
 		switch (opt) {
 		case 'i':
 			kernel_read = optarg;
@@ -2586,6 +2607,9 @@ int main(int argc, char **argv)
 			extsym_iter->file = optarg;
 			extsym_start = extsym_iter;
 			break;
+		case 'f':
+			writable_fptr_verbose = 1;
+			break;
 		case 'm':
 			modversions = 1;
 			break;
@@ -2692,6 +2716,11 @@ int main(int argc, char **argv)
 	}
 
 	free(buf.p);
+	if (writable_fptr_count && !writable_fptr_verbose)
+		warn("modpost: Found %d writable function pointer%s.\n"
+		     "To see full details build your kernel with:\n"
+		     "'make CONFIG_DEBUG_WRITABLE_FUNCTION_POINTERS_VERBOSE=y'\n",
+		     writable_fptr_count, (writable_fptr_count == 1 ? "" : "s"));
 
 	return err;
 }
diff --git a/security/Kconfig b/security/Kconfig
index 2a1a2d396228..3b7a71410f88 100644
--- a/security/Kconfig
+++ b/security/Kconfig
@@ -9,7 +9,7 @@ source "security/keys/Kconfig"
 
 config SECURITY_DMESG_RESTRICT
 	bool "Restrict unprivileged access to the kernel syslog"
-	default n
+	default y
 	help
 	  This enforces restrictions on unprivileged users reading the kernel
 	  syslog via dmesg(8).
@@ -19,10 +19,34 @@ config SECURITY_DMESG_RESTRICT
 
 	  If you are unsure how to answer this question, answer N.
 
+config SECURITY_PERF_EVENTS_RESTRICT
+	bool "Restrict unprivileged use of performance events"
+	depends on PERF_EVENTS
+	default y
+	help
+	  If you say Y here, the kernel.perf_event_paranoid sysctl
+	  will be set to 3 by default, and no unprivileged use of the
+	  perf_event_open syscall will be permitted unless it is
+	  changed.
+
+config SECURITY_TIOCSTI_RESTRICT
+	bool "Restrict unprivileged use of tiocsti command injection"
+	default y
+	help
+	  This enforces restrictions on unprivileged users injecting commands
+	  into other processes which share a tty session using the TIOCSTI
+	  ioctl. This option makes TIOCSTI use require CAP_SYS_ADMIN.
+
+	  If this option is not selected, no restrictions will be enforced
+	  unless the tiocsti_restrict sysctl is explicitly set to (1).
+
+	  If you are unsure how to answer this question, answer N.
+
 config SECURITY
 	bool "Enable different security models"
 	depends on SYSFS
 	depends on MULTIUSER
+	default y
 	help
 	  This allows you to choose different security modules to be
 	  configured into your kernel.
@@ -48,6 +72,7 @@ config SECURITYFS
 config SECURITY_NETWORK
 	bool "Socket and Networking Security Hooks"
 	depends on SECURITY
+	default y
 	help
 	  This enables the socket and networking security hooks.
 	  If enabled, a security module can use these hooks to
@@ -154,6 +179,7 @@ config HARDENED_USERCOPY
 	bool "Harden memory copies between kernel and userspace"
 	depends on HAVE_HARDENED_USERCOPY_ALLOCATOR
 	imply STRICT_DEVMEM
+	default y
 	help
 	  This option checks for obviously wrong memory regions when
 	  copying memory to/from the kernel (via copy_to_user() and
@@ -166,7 +192,6 @@ config HARDENED_USERCOPY
 config HARDENED_USERCOPY_FALLBACK
 	bool "Allow usercopy whitelist violations to fallback to object size"
 	depends on HARDENED_USERCOPY
-	default y
 	help
 	  This is a temporary option that allows missing usercopy whitelists
 	  to be discovered via a WARN() to the kernel log, instead of
@@ -191,10 +216,21 @@ config HARDENED_USERCOPY_PAGESPAN
 config FORTIFY_SOURCE
 	bool "Harden common str/mem functions against buffer overflows"
 	depends on ARCH_HAS_FORTIFY_SOURCE
+	default y
 	help
 	  Detect overflows of buffers in common string and memory functions
 	  where the compiler can determine and validate the buffer sizes.
 
+config FORTIFY_SOURCE_STRICT_STRING
+	bool "Harden common functions against buffer overflows"
+	depends on FORTIFY_SOURCE
+	depends on EXPERT
+	help
+	  Perform stricter overflow checks catching overflows within objects
+	  for common C string functions rather than only between objects.
+
+	  This is not yet intended for production use, only bug finding.
+
 config STATIC_USERMODEHELPER
 	bool "Force all usermode helper calls through a single binary"
 	help
diff --git a/security/Kconfig.hardening b/security/Kconfig.hardening
index af4c979b38ee..473e40bb8537 100644
--- a/security/Kconfig.hardening
+++ b/security/Kconfig.hardening
@@ -169,6 +169,7 @@ config STACKLEAK_RUNTIME_DISABLE
 
 config INIT_ON_ALLOC_DEFAULT_ON
 	bool "Enable heap memory zeroing on allocation by default"
+	default yes
 	help
 	  This has the effect of setting "init_on_alloc=1" on the kernel
 	  command line. This can be disabled with "init_on_alloc=0".
@@ -181,6 +182,7 @@ config INIT_ON_ALLOC_DEFAULT_ON
 
 config INIT_ON_FREE_DEFAULT_ON
 	bool "Enable heap memory zeroing on free by default"
+	default yes
 	help
 	  This has the effect of setting "init_on_free=1" on the kernel
 	  command line. This can be disabled with "init_on_free=0".
@@ -196,6 +198,20 @@ config INIT_ON_FREE_DEFAULT_ON
 	  touching "cold" memory areas. Most cases see 3-5% impact. Some
 	  synthetic workloads have measured as high as 8%.
 
+config PAGE_SANITIZE_VERIFY
+	bool "Verify sanitized pages"
+	default y
+	help
+	  When init_on_free is enabled, verify that newly allocated pages
+	  are zeroed to detect write-after-free bugs.
+
+config SLAB_SANITIZE_VERIFY
+	default y
+	bool "Verify sanitized SLAB allocations"
+	help
+	  When init_on_free is enabled, verify that newly allocated slab
+	  objects are zeroed to detect write-after-free bugs.
+
 endmenu
 
 endmenu
diff --git a/security/selinux/Kconfig b/security/selinux/Kconfig
index 5711689deb6a..fab0cb896907 100644
--- a/security/selinux/Kconfig
+++ b/security/selinux/Kconfig
@@ -3,7 +3,7 @@ config SECURITY_SELINUX
 	bool "NSA SELinux Support"
 	depends on SECURITY_NETWORK && AUDIT && NET && INET
 	select NETWORK_SECMARK
-	default n
+	default y
 	help
 	  This selects NSA Security-Enhanced Linux (SELinux).
 	  You will also need a policy configuration and a labeled filesystem.
@@ -65,23 +65,3 @@ config SECURITY_SELINUX_AVC_STATS
 	  This option collects access vector cache statistics to
 	  /selinux/avc/cache_stats, which may be monitored via
 	  tools such as avcstat.
-
-config SECURITY_SELINUX_CHECKREQPROT_VALUE
-	int "NSA SELinux checkreqprot default value"
-	depends on SECURITY_SELINUX
-	range 0 1
-	default 0
-	help
-	  This option sets the default value for the 'checkreqprot' flag
-	  that determines whether SELinux checks the protection requested
-	  by the application or the protection that will be applied by the
-	  kernel (including any implied execute for read-implies-exec) for
-	  mmap and mprotect calls.  If this option is set to 0 (zero),
-	  SELinux will default to checking the protection that will be applied
-	  by the kernel.  If this option is set to 1 (one), SELinux will
-	  default to checking the protection requested by the application.
-	  The checkreqprot flag may be changed from the default via the
-	  'checkreqprot=' boot parameter.  It may also be changed at runtime
-	  via /selinux/checkreqprot if authorized by policy.
-
-	  If you are unsure how to answer this question, answer 0.
diff --git a/security/selinux/hooks.c b/security/selinux/hooks.c
index 552e73d90fd2..46f1383d07d5 100644
--- a/security/selinux/hooks.c
+++ b/security/selinux/hooks.c
@@ -135,18 +135,7 @@ static int __init selinux_enabled_setup(char *str)
 __setup("selinux=", selinux_enabled_setup);
 #endif
 
-static unsigned int selinux_checkreqprot_boot =
-	CONFIG_SECURITY_SELINUX_CHECKREQPROT_VALUE;
-
-static int __init checkreqprot_setup(char *str)
-{
-	unsigned long checkreqprot;
-
-	if (!kstrtoul(str, 0, &checkreqprot))
-		selinux_checkreqprot_boot = checkreqprot ? 1 : 0;
-	return 1;
-}
-__setup("checkreqprot=", checkreqprot_setup);
+static const unsigned int selinux_checkreqprot_boot;
 
 /**
  * selinux_secmark_enabled - Check to see if SECMARK is currently enabled
diff --git a/security/selinux/selinuxfs.c b/security/selinux/selinuxfs.c
index e6c7643c3fc0..0e8217f72c5a 100644
--- a/security/selinux/selinuxfs.c
+++ b/security/selinux/selinuxfs.c
@@ -639,7 +639,6 @@ static ssize_t sel_read_checkreqprot(struct file *filp, char __user *buf,
 static ssize_t sel_write_checkreqprot(struct file *file, const char __user *buf,
 				      size_t count, loff_t *ppos)
 {
-	struct selinux_fs_info *fsi = file_inode(file)->i_sb->s_fs_info;
 	char *page;
 	ssize_t length;
 	unsigned int new_value;
@@ -663,10 +662,9 @@ static ssize_t sel_write_checkreqprot(struct file *file, const char __user *buf,
 		return PTR_ERR(page);
 
 	length = -EINVAL;
-	if (sscanf(page, "%u", &new_value) != 1)
+	if (sscanf(page, "%u", &new_value) != 1 || new_value)
 		goto out;
 
-	fsi->state->checkreqprot = new_value ? 1 : 0;
 	length = count;
 out:
 	kfree(page);
diff --git a/security/yama/Kconfig b/security/yama/Kconfig
index a810304123ca..b809050b25d2 100644
--- a/security/yama/Kconfig
+++ b/security/yama/Kconfig
@@ -2,7 +2,7 @@
 config SECURITY_YAMA
 	bool "Yama support"
 	depends on SECURITY
-	default n
+	default y
 	help
 	  This selects Yama, which extends DAC support with additional
 	  system-wide security settings beyond regular Linux discretionary
