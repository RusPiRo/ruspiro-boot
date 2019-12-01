/***********************************************************************************************************************
 * core boot code once the raspberry pi has powered.
 * The bootcode.bin ensures that all cores except core 0 is parked and the core 0 will be kicked off
 * executiung code at start adress 0x80000
 * Thus the entrypoint "__boot" need to link at adress 0x80000 when RusPiRo is build and linked into the
 * kernel8.img file
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/

.global __boot
.global __hang

.macro debug_lit_led num
    sub sp, sp, #16
    stp x0, x30, [sp, #0]
    
    mov x0, \num
    bl lit_led

    ldp x0, x30, [sp, #0]
    add sp, sp, #16
.endm

.section .text.boot 
__boot:
/***************************************************************
 * check for the current exception level we are running in
 * if we are already in EL1 we do not need to switch the EL
 * this is usually the case when we are run from the bootloader
 ***************************************************************/




/******************************************************
 * all cores execute the code here, so do the initialization
 * which is the same for all: setup stack pointer and switch
 * to execution level E1
 ******************************************************/
    // calculate stack pointer offset to be applied for this core
    mrs 	x0, mpidr_el1   // get CPU id
    and 	x0, x0, #3
    cbnz    x0, __hang

    ldr		x1,=__stack_top_core0__
	ldr		x2,=__stack_top_core1__
	subs    x1, x1, x2	// offset = core0 - core1
	mul 	x2, x1, x0  // core specific offset for the stack

/****************************************************
 * setup the initial stack pointer  - we usually start in EL2 mode...
 ****************************************************/
	ldr		x4,=__stack_top_EL2__
	sub		sp, x4, x2
    debug_lit_led #17

/****************************************************
 * setup the exception/interrupt handler table
 ****************************************************/
    ldr    x0, =VectorTable
    msr    vbar_el2, x0
    msr    vbar_el1, x0

/****************************************************
 * switch of MMU, D-cache and I-cache for EL1
 * for the reminder in case it was active
 ****************************************************/
    mrs     x0, sctlr_el1
    mov     x1, #(1 << 12 | 1 << 2 | 1 << 0)
    bic     x0, x0, x1
    msr     sctlr_el1, x0

/***************************************************
 * swith from EL2 to Supervisor Mode EL1
 ***************************************************/
	mrs		x0, CurrentEL	// read current execution level
	and		x0, x0, #12		// clear reserved bits

	ldr		x1,=__stack_top_EL1__ // prepare stack address for EL1 mode
	sub		x1, x1, x2
	
	cmp     x0, #4
	beq		.NoSwitch		// not in EL2 -> no switch (TODO: check for EL3?)

    msr     sp_el1, x1
	msr     sctlr_el1, xzr  // initialize SCTRL_EL1 register before switching to EL1
 	
    // enable AArch64 when switching to EL1 (otherwise EL1 would be executed in aarch32)
    mov     x0, #(1 << 31)      // AArch64
    orr     x0, x0, #(1 << 1)   // SWIO hardwired on Pi3
    msr     hcr_el2, x0
    mrs     x0, hcr_el2

	mrs     x2, cnthctl_el2 // enable CNTP for EL1
    orr     x2, x2, #3
    msr     cnthctl_el2, x2
    msr     cntvoff_el2, xzr

    // set the SPSR_EL2 to a valid value before returning to EL1
    mov     x2, #0x3c4 //#0b00101    // set DAIF to 0 and M[4] to 0 (exception from aarch64, M[3:0] to 0101 -> Exception from EL1h)
    msr     spsr_el2, x2	
    
    adr     x2, .SwitchReturn
    msr     elr_el2, x2
    eret

.NoSwitch:
.SwitchReturn:
    mov		sp, x1	// set the stack pointer for the current mode    
/******************************************************
 * as usage of NEON/FP is active by default in AARCH64
 * we will disable any trapping if used in any EL
 *******************************************************/
    // allow NEON/FP usage in EL0/1 --> Disable access trapping in EL1 and EL0.
    mrs x0, cpacr_el1
    mov x1, #(0x3 << 20) // FPEN disables trapping to EL1.
    orr x1, x0, x1
    msr cpacr_el1, x1
    //isb
    movi	v0.2d, #0x0

	// as we do not configure any EL routing of exceptions they are all
    // taken at EL1
    // activate interrupts by clearing the PSTATE mask
    msr     daifclr, #0x7 // enables SError, IRQ, FIQ

    debug_lit_led #18
    // for debugging initialze uart with basic settings
    bl init_uart
/******************************************************
 * setup MMU
 ******************************************************/
    bl      __setup_mmu

    debug_lit_led #20

/******************************************************
 * disable alignment checks (this only works if the MMU
 * is enabled). It's necessary as the compiler might
 * generate optimized code that does not care for proper
 * alignment for memory access.
 ******************************************************/
    mrs		x1, sctlr_el1
    mov     x2, #(1 << 1 | 1 << 3 | 1 << 4) 
	bic     x1, x1, x2  // clear SA0, SA and A bits
	msr     sctlr_el1, x1
	isb

/******************************************************
 * clear the BSS section
 ******************************************************/
.bss_init:
// get current CPUid
	mrs     x3, mpidr_el1
	and     x3, x3, #3
	cbnz	x3, .bss_done					// bss section clear only need to be done on core0

	/* Zero out the bss section right before switching into C mode to ensure all static initializations are done */
	ldr		x0, =__bss_start__
	ldr		x2, =__bss_end__
    sub     x2, x2, x0
    lsr     x2, x2, #3

.bss_zero_loop:
    cbz     x2, .bss_done
	str     xzr, [x0], #8
    sub     x2, x2, #1
    cbnz    x2, .bss_zero_loop

.bss_done:
    b		__rust_entry
/******************************************************
 * usually __rust_entry never returns, but in case it does
 * savely hang the CPU here
 ******************************************************/
    b       __hang

// hang any core. Save power with a "wait for event".
__hang:
    wfe
    b __hang
