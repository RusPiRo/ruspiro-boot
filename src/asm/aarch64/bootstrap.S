/***********************************************************************************************************************
 * Raspberry Pi bootstrap code.
 * This is the minimal preparation to brach into the "Rust" code line for further initialization
 * and setup for the current kernel to be run at the Raspberry Pi.
 * 
 * This is the Aarch64 version of the bootstrapping. It assumes:
 * 1. There is actually only the main core entering this code
 * 2. The bootcode.bin/start.elf have parked the other cores of the CPU
 * 3. The current core is entering this code in EL2
 * 4. The start address of the entry point is 0x8_0000 which has to be ensured by the linker script
 *
 *
 ***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann <pspwizard@gmx.de>
 * License: Apache License 2.0 / MIT
 **********************************************************************************************************************/

 .global __boot // global entry point
 .global __hang // helper to savely "hang" a core with nothing else to do

/***************************************************************************************************
 * main entry point using specific section that is ensured to be linked against the entrypoint
 * address 0x8_0000
 **************************************************************************************************/
.section .text.boot
__boot:
    // the very first thing to do is to setup the stack pointer.
    mrs 	x0, mpidr_el1   // get core id to calculate core distinct stack pointers
    and 	x0, x0, #3      
    
    ldr		x1,=__stack_top_core0__
	ldr		x2,=__stack_top_core1__
	subs    x1, x1, x2	// offset = core0 - core1
	mul 	x2, x1, x0  // core specific offset for the stack

    ldr		x1,=__stack_top_EL2__
    sub     sp, x1, x2

    // once done we clear the BSS section which contains any static field defined
    // in the Rust code line. This need to be properly initialized as it is expected
    // to be 0 when first accessed
    // as we might want to kickof other cores at a later point to also run the initial
    // bootstrap we check for the current core. As all cores share the same memory the
    // bss section need to and shall be cleared only once...
	cbnz	x0, .bss_done	    // only continue with bss clear on core 0

	ldr		x0, =__bss_start__  // linker file ensures alignment to 16Bit's for start and end
	ldr		x2, =__bss_end__ 
    sub     x2, x2, x0
    lsr     x2, x2, #4
    cbz     x2, .bss_done       // if bss section size is 0 -> skip initialization
.bss_zero_loop:
    
	stp     xzr, xzr, [x0], #16
    sub     x2, x2, #1
    cbnz    x2, .bss_zero_loop

.bss_done:
    // next step will switch from EL2 to EL1 which will be the one the kernel will be executed at
    bl      __switch_el2_to_el1
    // next we setup the exception vector table that will act as a trampoline for
    // all exceptions into the handler written in Rust code
    adr     x0, __ExceptionVectorTable
    msr     vbar_el1, x0    // set exception vector table adress in EL1

    // as rust compiler optimizations quite likely result in FP/NEON instructions
    // ensure they are not trapped
    mrs    x1, cpacr_el1
    mov    x0, #(3 << 20)
    orr    x0, x1, x0
    msr    cpacr_el1, x0

    // now call rust code entry point.
    mrs     x0, mpidr_el1       // read CoreId from register
	and     x0, x0, #3          // mask coreId value
    b   __rust_entry

    // usually this will never return. However to be an the save side, when ever we got back
    // safely hang this core
    b   __hang

/***************************************************************************************************
 * switch the current exception level EL2 to EL1. The EL1 return address is
 * the return to the caller
 **************************************************************************************************/
.global __switch_el2_to_el1
__switch_el2_to_el1:
    mrs     x0, currentEl   // get the current exception level
    cmp     x0, #(1 << 2)          // if already in EL1 no switch necessary
    beq     .SwitchReturn

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
    // this would have been usually set when capturing an exception from EL1 to EL2
    // as we would like to return we set the values as we would like to find them
    // configured once we are in EL1
    mov     x2, #(0b0101 << 0 | /* M[3:0] exception taken from El1h  */ \
                  0 << 4 | /* exception taken from aarch64 */ \
                  1 << 6 | /* mask FIQ */ \
                  1 << 7 | /* Mask IRQ */ \
                  1 << 8 | /* Mask Abort */ \
                  1 << 9)  /* Mask Debug */
    //mov     x2, #0x3c4 //#0b00101    // set DAIF to 0 and M[4] to 0 (exception from aarch64, M[3:0] to 0101 -> Exception from EL1h)
    msr     spsr_el2, x2
    
    // before returning to EL1 also ensure that interrupts are no longer routet to EL2
    mrs     x0, hcr_el2
    bic     x0, x0, #(1 << 3 | 1 << 4 | 1 << 5) // don't route Abort, IRQ and FIQ to EL2
    msr     hcr_el2, x0

    // we cannot directly return to the caller as the EL1 stackpointer
    // is not yet setup
    adr     x1, .SwitchReturn
    msr     elr_el2, x1
    eret    // return from EL2 -> EL1
.SwitchReturn:
    ldr     x1, =__stack_top_EL1__ // get the EL1 stack base address
    // use the core id to get the core specific stack pointer
    mrs 	x0, mpidr_el1   // get CPU id
    and 	x0, x0, #3

    ldr		x2,=__stack_top_core0__
	ldr		x3,=__stack_top_core1__
	subs    x2, x2, x3	// offset = core0 - core1
	mul 	x2, x2, x0  // core specific offset for the stack
    sub     x0, x1, x2  // from the top base substract the core offset to get final stack top
    mov     sp, x0
    ret

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
