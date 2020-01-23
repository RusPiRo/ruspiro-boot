/***************************************************************************************************
 * definition of the exception vector table 
 *
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **************************************************************************************************/
.global __ExceptionVectorTable

// specify the constants used to passed to the generic exception handler to identify
// the type and context of the exception raised
.equ EXC_CURREL_SP0_Sync,   0x1
.equ EXC_CURREL_SP0_Irq,    0x2
.equ EXC_CURREL_SP0_Fiq,    0x3
.equ EXC_CURREL_SP0_SErr,   0x4
.equ EXC_CURREL_SPX_Sync,   0x11
.equ EXC_CURREL_SPX_Irq,    0x12
.equ EXC_CURREL_SPX_Fiq,    0x13
.equ EXC_CURREL_SPX_SErr,   0x14
.equ EXC_LOWEREL64_SPX_Sync,    0x21
.equ EXC_LOWEREL64_SPX_Irq,     0x22
.equ EXC_LOWEREL64_SPX_Fiq,     0x23
.equ EXC_LOWEREL64_SPX_SErr,    0x24
.equ EXC_LOWEREL32_SPX_Sync,    0x31
.equ EXC_LOWEREL32_SPX_Irq,     0x32
.equ EXC_LOWEREL32_SPX_Fiq,     0x33
.equ EXC_LOWEREL32_SPX_SErr,    0x34

/***************************************************************************************************
 * default exception handler that does nothing for the time beeing
 * parameter passed: type, esr, spsr, far, elr
 **************************************************************************************************/
.weak __exception_handler_default
__exception_handler_default:
    nop
    ret

/***************************************************************************************************
 * generic exception handler trampoline
 * Input: X0 containing the id of the exception that has been raised
 **************************************************************************************************/
__exception_trampoline:
/**********************************************************************
 * save current core state before running any IRQ handler
 **********************************************************************/
	sub		sp, sp, #176 // make place at the stack to store all register values
	// register x19-x29 are callee save registers
	stp		x0, x1, [sp, #16 * 0]
	stp     x2, x3, [sp, #16 * 1]
	stp		x4, x5, [sp, #16 * 2]
	stp		x6, x7, [sp, #16 * 3]
	stp		x8, x9, [sp, #16 * 4]
	stp		x10, x11, [sp, #16 * 5]
	stp		x12, x13, [sp, #16 * 6]
	stp		x14, x15, [sp, #16 * 7]
    stp		x16, x17, [sp, #16 * 8]
    stp		x18, x30, [sp, #16 * 9]

	// stack SPSR_EL1 and ELR_EL1 for an optional re-entrant interrupt handler, which would require
    // to enable interrupts before the handler is called as they are deactivated on exception entrance
	mrs		x10, spsr_el1
	mrs		x11, elr_el1
	stp     x10, x11, [sp, #16 * 10]    // reading the context of the current exception to be passed to the handler
    
    // we assume this is taken in EL1 - therfore hardcode the respective registers
    mrs     x1, esr_el1
    mrs     x2, spsr_el1
    mrs     x3, far_el1
    mrs     x4, elr_el1

    // branch to the default exception handler
    // if not implemented somewhere else the default implementeation provided here will
    // be called, consumes x0-x4 as parameters
    bl      __exception_handler_default
    
/**********************************************************************
 * restore last core state after running any IRQ handler
 **********************************************************************/
    // restore SPSR_EL1 and ELR_EL1
	ldp		x10, x11, [sp, #16 * 10]
	msr     elr_el1, x11
	msr     spsr_el1, x10

	ldp		x0, x1, [sp, #16 * 0]
	ldp     x2, x3, [sp, #16 * 1]
	ldp		x4, x5, [sp, #16 * 2]
	ldp		x6, x7, [sp, #16 * 3]
	ldp		x8, x9, [sp, #16 * 4]
	ldp		x10, x11, [sp, #16 * 5]
	ldp		x12, x13, [sp, #16 * 6]
	ldp		x14, x15, [sp, #16 * 7]
    ldp		x16, x17, [sp, #16 * 8]
    ldp		x18, x30, [sp, #16 * 9]

	add		sp, sp, #176 // free the stack as it is no longer needed    
    ret

/**********************************************************************
 * Macro to call the exception trampoline ensuring scratch registers
 * are properly saved before and restored afterwards, takes the type value
 * for the exception as parameter
 **********************************************************************/
.macro call_trampoline type
    // store the scratch registers
    sub     sp, sp, #16
    stp     x0, x30, [sp]
    
    // call the exception trampoline
    mov     x0, \type
    bl      __exception_trampoline

    // restore the scratch registers
    ldp    x0, x30, [sp]
    add    sp, sp, #16
.endm

// the exception vector table start need to be proper aligned
// the order of entries and their alignments are specified in the respective ARM
// documents. Each vector table "section" can contain max 32 instructions
// so we use this entries just to jump to the real trampoline function
.balign 0x800
__ExceptionVectorTable:
// Sync Exception raised in current EL with SP_0
.EXC_CURREL_SP0_Sync:
    // call the exception trampoline
    call_trampoline EXC_CURREL_SP0_Sync
    eret // return from exception handler to normal processing

// Irq Exception raised in current EL with SP_0
.balign 0x80
.EXC_CURREL_SP0_Irq:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SP0_Irq
    eret // return from exception handler to normal processing

// Fiq Exception raised in current EL with SP_0
.balign 0x80
.EXC_CURREL_SP0_Fiq:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SP0_Fiq
    eret // return from exception handler to normal processing

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SP0_SErr:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SP0_SErr
    eret // return from exception handler to normal processing

/**************************************************************************************************/
// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Sync:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SPX_Sync
    eret // return from exception handler to normal processing

// Irq Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Irq:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SPX_Irq
    eret // return from exception handler to normal processing

// Fiq Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Fiq:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SPX_Fiq
    eret // return from exception handler to normal processing

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_SErr:
    // call the exception trampoline
    call_trampoline  EXC_CURREL_SPX_SErr
    eret // return from exception handler to normal processing

/**************************************************************************************************/
// Sync Exception raised in lower EL Aarch64 with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Sync:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL64_SPX_Sync
    eret // return from exception handler to normal processing

// Irq Exception raised in current EL Aarc64 with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Irq:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL64_SPX_Irq
    eret // return from exception handler to normal processing

// Fiq Exception raised in current EL with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Fiq:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL64_SPX_Fiq
    eret // return from exception handler to normal processing

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_SErr:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL64_SPX_SErr
    eret // return from exception handler to normal processing

/**************************************************************************************************/
// Sync Exception raised in lower EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Sync:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL32_SPX_Sync
    eret // return from exception handler to normal processing

// Irq Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Irq:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL32_SPX_Irq
    eret // return from exception handler to normal processing

// Fiq Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Fiq:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL32_SPX_Fiq
    eret // return from exception handler to normal processing

// Sync Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_SErr:
    // call the exception trampoline
    call_trampoline  EXC_LOWEREL32_SPX_SErr
    eret // return from exception handler to normal processing

.balign 0x80
__ExceptionVectorTableEnd:
