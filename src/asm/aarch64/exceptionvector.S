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

/**********************************************************************
 * save current core state before running any IRQ handler
 **********************************************************************/
.macro save_state
	sub		sp, sp, #256 // make place at the stack to store all register values
	
	stp		x0, x1, [sp, #16 * 0]
	stp     x2, x3, [sp, #16 * 1]
	stp		x4, x5, [sp, #16 * 2]
	stp		x6, x7, [sp, #16 * 3]
	stp		x8, x9, [sp, #16 * 4]
	stp		x10, x11, [sp, #16 * 5]
	stp		x12, x13, [sp, #16 * 6]
	stp		x14, x15, [sp, #16 * 7]
	stp		x16, x17, [sp, #16 * 8]
	stp		x18, x19, [sp, #16 * 9]
	stp		x20, x21, [sp, #16 * 10]
	stp		x22, x23, [sp, #16 * 11]
	stp		x24, x25, [sp, #16 * 12]
	stp		x26, x27, [sp, #16 * 13]
	stp		x28, x29, [sp, #16 * 14]
	str     x30, [sp, #16 * 15]

	// stack SPSR_EL2 and ELR_EL2
	mrs		x10, spsr_el2
	mrs		x11, elr_el2
	stp     x10, x11, [sp, #16 * 16]

.endm

/**********************************************************************
 * restore last core state after running any IRQ handler
 **********************************************************************/
.macro restore_state
	ldp		x0, x1, [sp, #16 * 0]
	ldp     x2, x3, [sp, #16 * 1]
	ldp		x4, x5, [sp, #16 * 2]
	ldp		x6, x7, [sp, #16 * 3]
	ldp		x8, x9, [sp, #16 * 4]
	ldp		x10, x11, [sp, #16 * 5]
	ldp		x12, x13, [sp, #16 * 6]
	ldp		x14, x15, [sp, #16 * 7]
	ldp		x16, x17, [sp, #16 * 8]
	ldp		x18, x19, [sp, #16 * 9]
	ldp		x20, x21, [sp, #16 * 10]
	ldp		x22, x23, [sp, #16 * 11]
	ldp		x24, x25, [sp, #16 * 12]
	ldp		x26, x27, [sp, #16 * 13]
	ldp		x28, x29, [sp, #16 * 14]
	ldr     x30, [sp, #16 * 15]

	// restore SPSR_EL2 and ELR_EL2
	ldp		x10, x11, [sp, #16 * 16]
	msr     elr_el2, x11
	msr     spsr_el2, x10

	add		sp, sp, #256 // free the stack as it is no longer needed
.endm

/***************************************************************************************************
 * default exception handler that does nothing for the time beeing
 * TODO: id a default sync excpetion handler needed to indicate data aborts
 *       and/or software exceptions ?
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
    // before handling an exception save the current register states to the stack
    save_state
    // reading the context of the current exception to be passed to the handler
    // we assume this is taken in EL2 - therfore hardcode the respective registers
    mrs     x1, esr_el2
    mrs     x2, spsr_el2
    mrs     x3, far_el2
    mrs     x4, elr_el2

    // branch to the default exception handler
    // if not implemented somewhere else the default implementeation provided here will
    // be called, consumes x0-x4 as parameters
    bl      __exception_handler_default
    // after handling an exception restore the previous register states
    restore_state
    eret // return from exception handler to normal processing

// the exception vector table start need to be proper aligned
// the order of entries and their alignments are specified in the respective ARM
// documents. Each vector table "section" can contain max 32 instructions
// so we use this entries just to jump to the real trampoline function
.balign 0x800
__ExceptionVectorTable:
// Sync Exception raised in current EL with SP_0
.EXC_CURREL_SP0_Sync:
    mov     x0, EXC_CURREL_SP0_Sync
    b       __exception_trampoline

// Irq Exception raised in current EL with SP_0
.balign 0x80
.EXC_CURREL_SP0_Irq:
    mov     x0, EXC_CURREL_SP0_Irq
    b       __exception_trampoline

// Fiq Exception raised in current EL with SP_0
.balign 0x80
.EXC_CURREL_SP0_Fiq:
    mov     x0, EXC_CURREL_SP0_Fiq
    b       __exception_trampoline

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SP0_SErr:
    mov     x0, EXC_CURREL_SP0_SErr
    b       __exception_trampoline
/**************************************************************************************************/
// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Sync:
    mov     x0, EXC_CURREL_SPX_Sync
    b       __exception_trampoline

// Irq Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Irq:
    mov     x0, EXC_CURREL_SPX_Irq
    b       __exception_trampoline

// Fiq Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_Fiq:
    mov     x0, EXC_CURREL_SPX_Fiq
    b       __exception_trampoline

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_CURREL_SPX_SErr:
    mov     x0, EXC_CURREL_SPX_SErr
    b       __exception_trampoline

/**************************************************************************************************/
// Sync Exception raised in lower EL Aarch64 with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Sync:
    mov     x0, EXC_LOWEREL64_SPX_Sync
    b       __exception_trampoline

// Irq Exception raised in current EL Aarc64 with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Irq:
    mov     x0, EXC_LOWEREL64_SPX_Irq
    b       __exception_trampoline

// Fiq Exception raised in current EL with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_Fiq:
    mov     x0, EXC_LOWEREL64_SPX_Fiq
    b       __exception_trampoline

// Sync Exception raised in current EL with SP_x
.balign 0x80
.EXC_LOWEREL64_SPX_SErr:
    mov     x0, EXC_LOWEREL64_SPX_SErr
    b       __exception_trampoline

/**************************************************************************************************/
// Sync Exception raised in lower EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Sync:
    mov     x0, EXC_LOWEREL32_SPX_Sync
    b       __exception_trampoline

// Irq Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Irq:
    mov     x0, EXC_LOWEREL32_SPX_Irq
    b       __exception_trampoline

// Fiq Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_Fiq:
    mov     x0, EXC_LOWEREL32_SPX_Fiq
    b       __exception_trampoline

// Sync Exception raised in current EL Aarch32 with SP_x
.balign 0x80
.EXC_LOWEREL32_SPX_SErr:
    mov     x0, EXC_LOWEREL32_SPX_SErr
    b       __exception_trampoline