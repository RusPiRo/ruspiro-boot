/***************************************************************************************************
 * Raspberry Pi bootstrap code.
 * This is the minimal preparation to brach into the "Rust" code line for further initialization
 * and setup for the current kernel to be run at the Raspberry Pi.
 * 
 * This is the Aarch32 version of the bootstrapping. It assumes:
 * 1. There is actually only the main core entering this code
 * 2. The bootcode.bin/start.elf have parked the other cores of the CPU
 * 3. The current core is entering this code in HYP
 * 4. The start address of the entry point is 0x8000 which has to be ensured by the linker script
 *
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **************************************************************************************************/

.global __boot // global entry point
.global __hang // helper to savely "hang" a core with nothing else to do

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


/***************************************************************************************************
 * main entry point using specific section that is ensured to be linked against the entrypoint
 * address 0x8000
 **************************************************************************************************/
.section .text.boot
__boot:
    // the very first thing to do is to setup the stack pointer
    mrc     p15, 0, r0, c0, c0, 5   // get core id to calculate distinct stack pointer
    and     r0, r0, #3

    ldr		r1,=__stack_top_core0__
	ldr		r2,=__stack_top_core1__
	subs    r1, r1, r2	// offset = core0 - core1
	mul 	r2, r1, r0  // core specific offset for the stack

    ldr		r3,=__stack_top_HYP__
	sub		sp, r3, r2

    // once done we clear the BSS section which contains any static field defined
    // in the Rust code line. This need to be properly initialized as it is expected
    // to be 0 when first accessed
    // as we might want to kickof other cores at a later point to also run the initial
    // bootstrap we check for the current core. As all cores share the same memory the
    // bss section need to and shall be cleared only once...
    cmp     r0, #0x0
    bne     .bss_done // only main core shall clear the BSS section

    ldr		r3, =__bss_start__
	ldr		r1, =__bss_end__
	mov 	r2, #0

.bss_zero_loop:
	cmp		r3, r1
	it		lt
	strlt	r2,[r3], #4
	blt		.bss_zero_loop

.bss_done:
	// next step will switch from HYP to SVC mode which will be the one the kernel will be executed at
	bl      __switch_hyp_to_svc

    // next we setup the exception vector table that will act as a trampoline for
    // all exceptions into the handler written in Rust code
    ldr		r0, =__ExceptionVectorTable
	mcr     p15, 0, r0, c12, c0, 0

    // as rust compiler optimizations quite likely result in FP/NEON instructions
    // ensure they are not trapped
    mrc		p15, 0, r0, c1, c0, 2
	orr 	r0, r0, #0x300000		/* enable single precision */
	orr 	r0, r0, #0xC00000		/* enable double precision */
	mcr 	p15, 0, r0, c1, c0, 2
	
	mov 	r0, #0x40000000
	vmsr	fpexc, r0

    // finally call into the rust code entry point
    mrc     p15, 0, r0, c0, c0, 5   // get core id
    and     r0, r0, #3
    b       __rust_entry

    // usually this will never return. However to be an the save side, when ever we got back
    // safely hang this core
    b   __hang

/***************************************************************************************************
 * switch the current execution mode from HYP mode to SVC mode
 **************************************************************************************************/
.global __switch_hyp_to_svc
__switch_hyp_to_svc:

	mov     r10, lr						// remeber return address
 	mrs 	r0, cpsr					// Get the CPSR
 	eor 	r0, r0, #ARM_MODE_HYP		// 
 	tst 	r0, #ARM_MODE_BITS			// Test for HYP mode
 	bic 	r0, r0, #ARM_MODE_BITS		// Clear the mode bits
	orr 	r0, r0, #ARM_I_BIT | ARM_F_BIT | ARM_MODE_SVC // Mask IRQ/FIQ bits and set SVC mode
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
    // we are now for sure running SVC mode
	// so setup the stack pointer based on the core id
    mrc     p15, 0, r0, c0, c0, 5   // get core id to calculate distinct stack pointer
    and     r0, r0, #3

    ldr		r1,=__stack_top_core0__
	ldr		r2,=__stack_top_core1__
	subs    r1, r1, r2	// offset = core0 - core1
	mul 	r2, r1, r0  // core specific offset for the stack

    ldr		r3,=__stack_top_SVC__
	sub		sp, r3, r2

	// once the initial stack pointer has been set also set the stackpointers for the different
	// execution modes FIQ, IRQ, ABT, SYS, UND
	mrs 	r1, cpsr					// Fetch the cpsr register which includes CPU mode bits
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_FIQ		// FIQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to FIQ_MODE
	ldr		sp,=__stack_top_FIQ__		// Set the stack pointer for FIQ_MODE
	sub     sp, sp, r2					// adjust with core specific offset
	
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_IRQ		// IRQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to IRQ_MODE
    ldr		sp,=__stack_top_IRQ__		// Set the stack pointer for IRQ_MODE
    sub     sp, sp, r2					// adjust with core specific offset

	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_ABT		// IRQ_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to ABT_MODE
    ldr		sp,=__stack_top_ABT__       // Set the stack pointer for IRQ_MODE
	sub     sp, sp, r2					// adjust with core specific offset
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_SYS		// SYS_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to SYS_MODE
    ldr		sp,=__stack_top_SYS__		// Set the stack pointer for IRQ_MODE
	sub     sp, sp, r2					// adjust with core specific offset
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_UND		// UND_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to UND_MODE
    ldr		sp,=__stack_top_UND__		// Set the stack pointer for ABORT_MODE
	sub     sp, sp, r2					// adjust with core specific offset
    
	bic 	r1, r1, #0x1F				// Clear the CPU mode bits in register r0
	orr 	r1, r1, #ARM_MODE_SVC		// SVC_MODE bits onto register with Irq/Fiq disabled
    msr 	CPSR_c, r1					// Switch to SVC_MODE again all stacks ready to go

	bx      r10			// return to the caller beeing in SVC now

/***************************************************************************************************
 * savely hang the core
 * use the WFE instruction to save power while waiting for any event
 * wfe is triggered by any exception/interrupt raised, but as long as there is no event
 * the core sleeps....
 **************************************************************************************************/
 .section .text
 __hang:
    wfe
    b   __hang


/****************************************************************************
 ****************************************************************************/
__entry32:
    // get current CPUid to pass it to the entry function
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3

	lsl     r1, r0, #3
    mov     r4, #0
	mov     r5, #0
	mov     r3, #0xd8
    strd    r4, r5, [r3, r1]

    ldr     r1, =0x400000CC // core 0 mailbox 3 set

.park32:
    wfe
    ldr     r2, [r1, r0, lsl #4] // read core specific mailbox
    cmp     r2, #0
    beq     .park32
	str     r2, [r1, r0, lsl #4] // clear mailbox by writing to it
    bx      r2
