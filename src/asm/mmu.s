/***********************************************************************************************************************
 * Raspberry Pi3 MMU related functions
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
.global __invalidate_ttlb
.global __setup_mmu

/**********************************************************
 * setup the TTLB table at 0x4000
 * uses r0, r1, r2, r3, r4
 **********************************************************/
__setup_ttlb:             // N   A
	push	{r0-r4, lr}
	ldr		r0, =0x4000  // S0G X   AP DOMN C
	mov		r1, #0x0     // 1  S1TEX1 P    X B10
	                     // 9   5   1  8  5 3  0
//ldr		r2, =0x90C0E // 10010000110000001110 --> shareable, outer/inner write back no allocate
//ldr		r2, =0x90C0A     // 10010000110000001010 --> shareable, outer/inner write through no allocate on write
//    ldr	r2, =0x91C0E // 10010001110000001110 --> shareable, outer/inner write back, allocate on write
//ldr		r2, =0x91C02 // 10010001110000000010 --> (normal, outer/inner non cacheable, shared)	
	ldr     r2,          =0b00000000110000011110 //--> shareable, outer/inner write back, allocate on write
	ldr		r4, =0x4FC0

.loop1:						// write 4096 entries to MMUTable
	orr		r3, r1, r2
	str		r3, [r0], #4			// store the value at r0 address and increment r0 address by 4
	add		r1, r1, #0x100000
	cmp		r0, r4		// TLB 0000 0000 - 3F00 0000
	bne		.loop1
//                          N  S TEXAPP    XCB
	ldr		r2, =0x90C16 // 10010000110000010110 --> shared device
	ldr		r4, =0x8000

.loop2:						// write 4096 entries to MMUTable
	orr		r3, r1, r2
	str		r3, [r0], #4			// store the value at r0 address and increment r0 address by 4
	add		r1, r1, #0x100000
	cmp		r0, r4		// TLB 3F00 0000 - FF00 0000
	bne		.loop2

	pop		{r0-r4, lr}
	bx		lr

__invalidate_ttlb:
    push    {r0, lr}
    mov     r0, #0
    mcr		p15, 0, r0, c8, c7, 0	// invalidate unified TLB
    mcr		p15, 0, r0, c8, c3, 0	// invalidate entire inner sharable TLB
    mcr		p15, 0, r0, c8, c5, 0	// invalidate instruction TLB
    mcr		p15, 0, r0, c8, c6, 0   // invalidate data TLB
    dsb
    isb

    pop     {r0, lr}
    bx		lr

__setup_mmu:
/******************************************************
 * setup the MMU
 *
 * to do so we need to write the CPU extended control
 * register. But this seem to need enablement in
 * auxiliary control register
 ******************************************************/
    push    {r0 - r4, lr}
 	mrc 	p15, 0, r0, c1, c0, 1	// read current ACTRL register
 	orr 	r0, r0, #0x3			// set bit 0,1 --> enable write to CPUECTRL and ACTRL
 	mcr 	p15, 0, r0, c1, c0, 1   // write ACTRL register

//	mrrc 	p15, 1, r0, r1, c15		// read current CPUECTRL config
//	orr		r0, r0, #64				// set bit 6 --> SMPenable
//	mcrr	p15, 1, r0, r1, c15		// write CPUECTRL config

	mov		r0, #0x0
	mcr		p15, 0, r0, c2, c0, 2	// write TTB control register
	isb

// get current CPUid
	mrc		p15, 0, r3, c0, c0, 5		/* read MPIDR */
	and     r3, r3, #3
	cmp		r3, #0x0			// setup ttlb table entries only on core 0
	bne		.ttlb_ready2
	
	bl		__setup_ttlb		// setup MMU translation table at 0x4000

.ttlb_ready2:
	ldr		r0, =0x406a
	mcr		p15, 0, r0, c2, c0, 0	// set TT base register 0 to MMUTable
	isb

	ldr		r0, =0xFFFFFFFF			// set MMU domains all client
	mcr		p15, 0, r0, c3, c0, 0
	isb

/******************************************************
 * enable the instruction and data cache
 ******************************************************/
	mrc 	p15, 0, r0, c1, c0, 0
	ldr		r1, =0xfffffffd
	and		r0, r0, r1 					// enable unaligned access
	orr 	r0, r0, #(0x1 << 12)		// enable I-cache
// TODO: activate the d-cache. It's currently not usable as
// clearing/invalidating the cache seem not to work propperly
// as seen in the mailbox interface, so no active D-cache for the moment
	orr 	r0, r0, #(0x1 << 2)			// enable D-Cache
	mcr		p15, 0, r0, c1, c0, 0
	dsb
	isb

/******************************************************
 * enable the MMU
 ******************************************************/
	mrc 	p15, 0, r0, c1, c0, 0
	orr 	r0, r0, #0x1				/* enable MMU */
	mcr		p15, 0, r0, c1, c0, 0
	isb
    
    pop     {r0 - r4, lr}
    bx lr
