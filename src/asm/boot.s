/**
 * core boot code once the raspberry pi has powered.
 * The bootcode.bin ensures that all cores except core 0 is parked and the core 0 will be kicked off
 * executiung code at start adress 0x800
 * Thus the entrypoint "__boot" need to link at adress 0x800 when the rubo is build and linked into the kernel7.img file
 *
 * Author: André Borrmann
 * License: ???
 */
 
.global __boot
.global __hang

.equ ARM_MODE_BITS,	0x1F  /* bit mask for CPU mode from CPSR register */
.equ ARM_MODE_USR,	0x10  /* Normal User Mode */
.equ ARM_MODE_FIQ,  0x11  /* FIQ Processing Fast Interrupts Mode */
.equ ARM_MODE_IRQ,  0x12  /* IRQ Processing Standard Interrupts Mode */
.equ ARM_MODE_SVC,  0x13  /* Supervisor Processing Software Interrupts Mode */
.equ ARM_MODE_MON,  0x16  /* Secure Monitor Mode (For Secure / Non Secure Switching) */
.equ ARM_MODE_ABT,  0x17  /* Abort Processing memory Faults Mode */
.equ ARM_MODE_HYP,  0x1A  /* Hypervisor Mode */
.equ ARM_MODE_UND,  0x1B  /* Undefined Processing Undefined Instructions Mode */
.equ ARM_MODE_SYS,  0x1F  /* System Running Priviledged Operating System Tasks Mode */

.equ ARM_I_BIT,     0x080 /* IRQs disabled when set to 1 */
.equ ARM_F_BIT,     0x040 /* FIQs disabled when set to 1 */
.equ ARM_A_BIT,     0x100 /* Data Abort masked when set to 1 */

.section .text.boot /* ensure this entrypoint links always to the start address */
__boot:
/******************************************************
 * the boot process depends on the CPU id, 
 * as for example the stack pointer calculation
 ******************************************************/
// get current CPUid
	mrc		p15, 0, r3, c0, c0, 5		/* read MPIDR */
	and     r3, r3, #3

// calculate stack pointer offset to be applied for each core
	ldr		r1,=__stack_top_core0__
	ldr		r2,=__stack_top_core1__
	subs    r1, r1, r2	// offset = core0 - core1
	mul 	r2, r1, r3  // core specific offset for the stack

/****************************************************
 * setup the initial stack pointer  - we usually start in HYP mode...
 ****************************************************/
	ldr		sp,=__stack_top_HYP__
	sub		sp, sp, r2

/****************************************************
 * setup the interrupt handler table
 ****************************************************/
 	cmp		r3, #0x0
	bne     .irq_prepared
	push	{r0 - r3}
	/* copy the 16 entries from the irq-handler table to 0x0, each one is an address to the handler itself */
	ldr		r0, =__irq_trampolines
	mov		r1, #0x0
	ldmia   r0!,{r2-r9}	// load 8x 32bit values from source
    stmia   r1!,{r2-r9} // store 8x 32bit values to target
    ldmia   r0!,{r2-r9} // load 8x 32bit values from source
    stmia   r1!,{r2-r9} // store 8x 32bit values to target
	pop		{r0 - r3}
	
.irq_prepared:
/*****************************************************
 * invalidate caches and TLB
 *****************************************************/
 	mov		r0, #0
 /* Disable ICache and DCache during start-up */
	bic 	r0, r0, #(0x1 << 12)		/* disable I-cache */
	bic 	r0, r0, #(0x1 << 2)			/* disable D-Cache */
	dsb
	mcr		p15, 0, r0, c1, c0, 0
	isb

	bl		__invalidate_ttlb
	//bl		__invalidate_dcache		// invalidate the whole d-cache

	/* Disable MMU, if enabled */
	mrc		p15, 0, r0, c1, c0, 0		/* read CP15 register 1 */
	bic		r0, r0, #0x1				/* clear bit 0 */
	mcr		p15, 0, r0, c1, c0, 0		/* write value back */
	dsb
	isb

/*****************************************************
 * ensure we are running in Supervisor SVC mode from
 * now on in case we were in HYP
 *****************************************************/
 	mrs 	r0, cpsr					// Get the CPSR
 	eor 	r0, r0, #ARM_MODE_HYP		// Test for HYP mode
 	tst 	r0, #ARM_MODE_BITS			// Clear the mode bits
 	bic 	r0, r0, #ARM_MODE_BITS		// Mask IRQ/FIQ bits and set SVC mode
	orr 	r0, r0, #ARM_I_BIT | ARM_F_BIT | ARM_MODE_SVC
 	bne 	.NoSwitch					// no need to switch if not in HYP mode

 	orr 	r0, r0, #ARM_A_BIT			// Mask the Abort bit
 	adr 	r1, .SwitchReturn			// store the address to call when leaving HYP mode
 	msr 	spsr_cxsf, r0				// set the SPSR

	msr 	ELR_hyp, r1 				// enter SVC mode and load r1 address to ELR_hyp
	eret             					// jumps to the address in ELR_hyp

.NoSwitch:
 	//Set the CPSR (C fields)
 	msr cpsr_c, r0						// which would just set the SVC mode

.SwitchReturn:
/******************************************************
 * as we are now in the desired mode (SVC) we can switch
 * to each mode and set the necessary stack pointers
 ******************************************************/
	ldr		sp,=__stack_top_SVC__		// load stackpointer for SVC mode
	sub		sp, sp, r2
	
	mrs 	r1, cpsr					// Fetch the cpsr register which includes CPU mode bits
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_FIQ		// FIQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to FIQ_MODE
	ldr		sp,=__stack_top_FIQ__		// Set the stack pointer for FIQ_MODE
	sub     sp, sp, r2
	
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_IRQ		// IRQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to IRQ_MODE
    ldr		sp,=__stack_top_IRQ__		// Set the stack pointer for IRQ_MODE
    sub     sp, sp, r2

	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_ABT		// IRQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to ABT_MODE
    ldr		sp,=__stack_top_ABT__       // Set the stack pointer for IRQ_MODE
	sub     sp, sp, r2
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_SYS		// SYS_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to SYS_MODE
    ldr		sp,=__stack_top_SYS__		// Set the stack pointer for IRQ_MODE
	sub     sp, sp, r2
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_UND		// UND_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to UND_MODE
    ldr		sp,=__stack_top_UND__		// Set the stack pointer for ABORT_MODE
	sub     sp, sp, r2
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_SVC		// SVC_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to SVC_MODE again all stacks ready to go
	
	dsb
	isb

	// enable interrupts (IRQ/FIRQ)
    cpsie	i
    cpsie	f

	// setup the MMU
	bl __setup_mmu

/******************************************************
 * enable FPU/NEON processing for floating point
 * arithmetics
 ******************************************************/
	mrc		p15, 0, r0, c1, c0, 2
	orr 	r0, r0, #0x300000		/* enable single precision */
	orr 	r0, r0, #0xC00000		/* enable double precision */
	mcr 	p15, 0, r0, c1, c0, 2
	mov 	r0, #0x40000000
	fmxr	fpexc, r0	

.bss_init:
// get current CPUid
	mrc		p15, 0, r3, c0, c0, 5		/* read MPIDR */
	and     r3, r3, #3
	cmp		r3, 0x0					// bss init only need to be done on core0
	bne		.bss_done

/******************************************************
 * clear the BSS section
 ******************************************************/
	/* Zero out the bss section right before switching into C mode to ensure all static initializations are done */
	ldr		r0, =__bss_start__
	ldr		r1, =__bss_end__
	mov 	r2, #0

.bss_zero_loop:
	cmp		r0, r1
	it		lt
	strlt	r2,[r0], #4
	blt		.bss_zero_loop

.bss_done:
	// get current CPUid to pass it to the entry function
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3
/*******************************************************
 * this is the entry point into the RUST environment
 *******************************************************/
	bl		__come_alive
	
/******************************************************
 * kickoff the next core
 ******************************************************/
// get current CPUid
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3
	cmp		r0, 0x3
	bge     .no_further_core // no further core need to be kicked off

	ldr		r1, =__boot		// each core start at the same entry point
	ldr		r2, =0x4000008C // inter core mailbox base address for core 0
	mov     r4, 0x10		// core mailbox offset between cores
	add     r3, r0, 1		// add 1 to the current core id to kick off the next one
	mul		r3, r3, r4   	// core mailbox offset for the next core
	str 	r1, [r2, r3]		// set start address of the next core
	sev						// kick off next core as it was suspended with wfe

.no_further_core:
/*******************************************************
 * this is the second entry point into the RUST en-
 * vironment aiming for an endless running task on this core
 *******************************************************/
	// get current CPUid to pass it to the entry function
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3
	bl __run				// this usually never returns! r0 = current core id passed along

/******************************************************
 * usually __entry never returns, but in case it does
 * savely hang the CPU here
 ******************************************************/
__hang:
	b	__hang


