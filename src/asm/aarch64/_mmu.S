/***********************************************************************************************************************
 * Raspberry Pi3 MMU related functions
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
.macro debug_lit_led num
    sub sp, sp, #16
    stp x0, x30, [sp, #0]
    
    mov x0, \num
    bl lit_led

    ldp x0, x30, [sp, #0]
    add sp, sp, #16
.endm
/**********************************************************
 * setup the TTLB table at 0x40000
 **********************************************************/
__setup_ttlb:
	//stp		x0, x30, [sp, #-16]!
	// set the start address of the translation table to be at 0x40000
	mov		x0, 0x40000

	// set the level 0 entries.
	// this is just two entry which is a table entry pointing to the next translation level
	// this is required when using 4kB granule translation mapping
	// one entry contains the address to the next level table bits [47:12]
	// and covers 1GB virtual address space 0x0000_0000 - 0x4000_0000
	// as we need to address some device memory up to 0x4000_2000 we have 2 entries here
	// spanning theoretically 2GB
	mov     x3, #1
	lsl     x3, x3, #63

	ldr     x1, =0x41000 // the base address of the next level
	orr     x2, x1, #0b11 // set the bits to mark this a table entry
	orr     x2, x2, x3    // set bit 63 (NSTable)
	str     x2, [x0], #8      // store this entry at 0x40000

	ldr     x1, =0x42000    // the base address of the next level
	orr     x2, x1, #0b11 // set the bits to mark this a table entry
	orr     x2, x2, x3    // set bit 63 (NSTable)
	str     x2, [x0]      // store this entry at 0x40008

	// set the level 1 entries.
	// each of those entries cover 2MB virtual address space for the 1GB block defined by it's
	// level 0 entry. This would lead to 512 entries on level 1 that for the time beeing define
	// the 1:1 memory mapping as block entries with their specific attributes
	ldr		x0, =0x41000
	mov     x1, #0x0 // the physical address to be stored in the mapping table bits for 1:1 mapping
	mov     x9, #504 // map this many first entries (0x0000_0000 - 0x3E00_0000)

.lvl2_loop1:
	orr     x2, x1, #0b01  // set the bits to mark this a block entry
	mov		x3, #0x710
	orr     x2, x2, x3 	   // set the memory block attributes AF=1, SH=inner shareable, normal Mem
	                       // AF= 1 << 10
						   // SH= 3 << 8
						   // memAttr= 4 << 2 (index to MAIR)					   
	str		x2, [x0], #8   // store this entry in the table and increase the pointer
	add     x1, x1, #0x200000 // increase physical address this block points to by 2MB
	sub     x9, x9, #1
	cbnz    x9, .lvl2_loop1

	// after the first 504 entries we start to map the device memory (0x3F00_0000-0x4000_0000)
	mov		x9, #8

.lvl2_loop2:
	orr     x2, x1, #0b01  // set the bits to mark this a block entry
	orr     x2, x2, #0x400 // set the memory block attributes AF=1, SH=0, device Mem
	                       // AF= 1 << 10
						   // SH= 0 << 8
						   // memAttr= 0 << 2 (index to MAIR)					   
	str		x2, [x0], #8   // store this entry in the table and increase the pointer
	add     x1, x1, #0x200000 // increase physical address this block points to by 2MB
	sub     x9, x9, #1
	cbnz    x9, .lvl2_loop2


	// after the first 512 level 1 entries we need another one at 0x42000
	// this one is for the core mailboxes and therefore specific device memory
	ldr		x0, =0x42000
	movz    x1, #0x4000, lsl 16

	orr     x2, x1, #0b01 // this is a block entry
	orr     x2, x2, #0x400  // set the memory block attributes AF=1, SH=0, device Memory
	                      // AF= 1 << 10
						  // SH= 0 << 8
						  // memAttr= 0 << 2 (index to MAIR)

	//ldp		x0, x30, [sp], #16
	ret	

.balign 4
.ltorg


// define some MMU config values (the multiline trick only works with gcc pre-processing the assembly file using ".S" [capital S] extension)
.equ MAIR_EL1_VAL, ( (0x0UL << 0) |  /* Device NGNRNE */ \
                     (0x04UL << 8) | /* Device NGNRE */ \
					 (0x0CUL << 16) |/* Device GRE */ \
					 (0x44UL << 24) |/* Normal NC */ \
					 (0xFFUL << 32) ) /* Normal */

.equ TCR_EL1_VAL, ( (0b00UL  << 37) |		/* TBI */ \
                    (0b000UL << 32) | 		/* IPS */ \
					(0b10UL  << 30) |		/* TG1 */ \
					(0b11UL  << 28) |		/* SH1 */ \
					(0b01UL  << 26) |		/* ORGN1 */ \
					(0b01UL  << 24) |		/* IRGN1 */ \
					(0b0UL   << 23) |		/* EPD1 - = 0 -> enable TTBR1 walk*/ \
					(25UL    << 16) |		/* T1SZ - 25 -> 512G, Regionsize 2^(64-T1SZ) */ \
					(0b00UL  << 14) |		/* TG0 */ \
					(0b11UL  << 12) |		/* SH0 */ \
					(0b01UL  << 10) |		/* ORGN0 */ \
					(0b01UL  << 8) |		/* IRGN0 */ \
					(0b0UL   << 7) |		/* EPD0 - = 0 -> enable TTBR0 walk */ \
					(25UL    << 0) )		/* T0SZ - 25 -> 512G, Regionsize 2^(64-T0SZ) */

.equ SCTRL_EL1_VAL, ( (0xC00800) |	/* mandatory reserved bits */ \
                      (1 << 12) |	/* I - instruction cache */ \
					  (1 << 4)  |	/* SA0, stack alignment check EL0 */ \
					  (1 << 3)  |	/* SA, stack alignment check */ \
					  (1 << 2)	|	/* C, data cache */ \
					  (1 << 1)	|	/* A, alignment check */ \
					  (1 << 0) )	/* M, MMU enable */

.global __setup_mmu
__setup_mmu:
/******************************************************
 * setup the MMU
 * input: w0  CPU-ID
 ******************************************************/
	sub		sp, sp, #16
	stp		x0, x30, [sp]
	mov     x20, x30

	mrs 	x0, mpidr_el1   // get CPI id
    and 	x0, x0, #3
	cbnz	x0, .ttlb_ready	// all cores other than 0 just do the MMU setup. trabslation tables are prepared only on core 0
	
	bl		__setup_ttlb
	dsb		ishst
	
	/*tlbi	alle1is
	dsb		ish
	isb*/

.ttlb_ready:
	// configure MAIR
	ldr		x1, =MAIR_EL1_VAL
	msr		mair_el1, x1

	// store the translation table address in TTBR0 and TTBR1 register
	ldr		x1, =0x40000
	msr     ttbr0_el1, x1
	msr		ttbr1_el1, x1
	isb

	// set the TCR_EL1
	ldr		x1, =TCR_EL1_VAL
	msr     tcr_el1, x1
	isb

	// enable SMPEN bit to ensure cache coherency between cores (hangs in EL1)
	//mrs 	x0, s3_1_c15_c2_1
	//orr 	x0, x0, #(0x1 << 6) // The SMP bit.
	//msr 	s3_1_c15_c2_1, x0
	
	// finally set the system control register to activate the MMU
	mrs		x1, sctlr_el1
	ldr		x2, =SCTRL_EL1_VAL
	orr     x1, x1, x2
	msr     sctlr_el1, x1
	isb
	nop

	debug_lit_led #20
	
	ldp		x0, x30, [sp]
	add     sp, sp, #16

	// check whats now in X30 / x20
	mov x0, x30
	bl dump_hex

	mov x0, x20
	bl dump_hex
	
	dsb     sy	

	ret		x20

.balign 4
.ltorg
