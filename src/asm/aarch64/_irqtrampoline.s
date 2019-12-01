/***********************************************************************************************************************
 * Initial setup for the Interrupt trampoline functions that will branch into rust environment
 * in case the corresponding Exception/Interrupt is raised
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
.global VectorTable
.global __exception_handler_Default
.global __interrupt_handler_Default
	
/**********************************************************************
 * implementation of the trampolines
 **********************************************************************/
__sync_trampoline:
	ret

__irq_trampoline:
	// stack the current state (before exception handling)
	stp		x0, x1, [sp, #-16]!
	stp		x2, x3, [sp, #-16]!
	stp		x4, x5, [sp, #-16]!
	stp		x6, x7, [sp, #-16]!
	stp		x8, x9, [sp, #-16]!
	stp		x10, x11, [sp, #-16]!
	stp		x12, x13, [sp, #-16]!
	stp		x14, x15, [sp, #-16]!
	stp		x16, x17, [sp, #-16]!
	stp		x18, x19, [sp, #-16]!
	stp		x20, x21, [sp, #-16]!
	stp		x22, x23, [sp, #-16]!
	stp		x24, x25, [sp, #-16]!
	stp		x26, x27, [sp, #-16]!
	stp		x28, x29, [sp, #-16]!
	stp		x30, x0, [sp, #-16]!

	// stack SPSR_EL1 and ELR_EL1
	mrs		x0, spsr_el1
	mrs		x1, elr_el1
	stp     x0, x1, [sp, #-16]!

	bl __interrupt_h

	// restore SPSR_EL1 and ELR_EL1
	ldp		x0, x1, [sp], #16
	msr     elr_el1, x1
	msr     spsr_el1, x0
	
	// restore the state from before eyception handling
	ldp		x30, x0, [sp], #16
	ldp		x28, x29, [sp], #16
	ldp		x26, x27, [sp], #16
	ldp		x24, x25, [sp], #16
	ldp		x22, x23, [sp], #16
	ldp		x20, x21, [sp], #16
	ldp		x18, x19, [sp], #16
	ldp		x16, x17, [sp], #16
	ldp		x14, x15, [sp], #16
	ldp		x12, x13, [sp], #16
	ldp		x10, x11, [sp], #16
	ldp		x8, x9, [sp], #16
	ldp		x6, x7, [sp], #16
	ldp		x4, x5, [sp], #16
	ldp		x2, x3, [sp], #16
	ldp		x0, x1, [sp], #16
	
    eret	// return from exception handling to normal processing

__fiq_trampoline:
	eret

__irq_hang:
    b   __irq_hang

__serror_trampoline:
	eret


.weak __exception_handler_Default
__exception_handler_Default:
	eret

.weak __interrupt_handler_Default
__interrupt_handler_Default:
	eret

/********************************************************************
 * The vector table for aarch64 exceptions
 * The table need to start at a 2kB aligned address and store the 
 * different entries each aligned to 128Byte containing at most 32
 * instructions. Usually each exception level does have it's own table
 * but we will re-use the same for all levels
 ********************************************************************/
.balign 0x800
VectorTable:
EXC_CURREL_SP0_Sync:
    b   __hang

.balign 0x80
EXC_CURREL_SP0_Irq:
	b __irq_trampoline

.balign 0x80
EXC_CURREL_SP0_FIq:
    b   __hang

.balign 0x80
EXC_CURREL_SP0_SErr:
    b   __hang

.balign 0x80
EXC_CURREL_SPX_Sync:
    b   __hang

.balign 0x80
EXC_CURREL_SPX_Irq:
    b   __hang

.balign 0x80
EXC_CURREL_SPX_FIq:
    b   __hang

.balign 0x80
EXC_CURREL_SPX_SErr:
    b   __hang
