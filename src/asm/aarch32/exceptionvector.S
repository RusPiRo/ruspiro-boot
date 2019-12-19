/***********************************************************************************************************************
 * Initial setup for the Interrupt trampoline functions that will branch into rust environment
 * in case the corresponding Exception/Interrupt is raised
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
.global __ExceptionVectorTable

// specify the constants used to passed to the generic exception handler to identify
// the type and context of the exception raised
.equ EXC_UNDEFINED_INSTRUCTION,     0x50
.equ EXC_SOFTWARE_INTERRUPT,        0x51
.equ EXC_PREFETCH_ABORT,            0x52
.equ EXC_DATA_ABORT,                0x53
.equ EXC_IRQ,                       0x54
.equ EXC_FIQ,                       0x55

/**********************************************************************
 * save current core state before running any IRQ handler
 **********************************************************************/
.macro save_state
    stmfd	sp!, {r0-r3, lr}  // store unbanked corruptile registers +  return address
    //mrs     r0, spsr    // get the saved pstate register and store it as well
    //stmfd   sp!, {r0}
    
    vmrs    r0, fpscr     // store VFP registers
    stmfd   sp!, {r0}
    vstmdb  sp!, {d0-d15}
.endm

/**********************************************************************
 * restore last core state after running any IRQ handler
 **********************************************************************/
.macro restore_state_return
    vldmia  sp!, {d0-d15}   // restore VFP registers
    ldmfd   sp!, {r0}
    vmsr    fpscr, r0

    //ldmfd   sp!, {r0}   // restore pstate
    //mcr     cpsr, r0
    ldmfd	sp!, {r0-r3, pc}^ // restore unbanked corruptile registers
.endm

/***************************************************************************************************
 * default exception handler that does nothing for the time beeing
 * parameter passed: type, spsr, sp_irq, lr_irq
 **************************************************************************************************/
.weak __exception_handler_default
__exception_handler_default:
    nop
    bx   lr

/****************************************************
 * quite a convinient way to define the IRQ table entries as
 * jump addresses to the respective IRQ trampolines
 ****************************************************/
 .align 8
 __ExceptionVectorTable:
    ldr 	pc, __reset_trampoline_addr
    ldr 	pc, __undefined_instruction_trampoline_addr
    ldr 	pc, __software_interrupt_trampoline_addr
    ldr 	pc, __prefetch_abort_trampoline_addr
    ldr 	pc, __data_abort_trampoline_addr
    ldr 	pc, __unused_trampoline_addr
    ldr 	pc, __interrupt_trampoline_addr
    ldr 	pc, __fast_interrupt_trampoline_addr

// now the trampoline place holders:
__reset_trampoline_addr:                     .word   __reset_trampoline
__undefined_instruction_trampoline_addr:     .word   __undefined_instruction_trampoline
__software_interrupt_trampoline_addr:        .word   __software_interrupt_trampoline
__prefetch_abort_trampoline_addr:            .word   __prefetch_abort_trampoline
__data_abort_trampoline_addr:                .word   __data_abort_trampoline
__unused_trampoline_addr:                    .word   __unused_trampoline
__interrupt_trampoline_addr:                 .word   __interrupt_trampoline
__fast_interrupt_trampoline_addr:            .word   __fast_interrupt_trampoline


/**********************************************************************
 * implementation of the trampolines
 **********************************************************************/
__reset_trampoline:
    b   __hang

__undefined_instruction_trampoline:
    save_state          

	fmrx	r0, fpexc		// check for floating point exception as this is recoverable
	tst		r0, #0x80000000	// EX bit set in FPEXC?
	bne		__floating_point_ex

    mov     r0, #EXC_UNDEFINED_INSTRUCTION // set the exception type
    mrs     r1, spsr        // get SPSR
    cps     #0x12           // switch to IRQ mode to get sp_irq and lr_irq
    mov     r2, sp
    mov     r3, lr
    cps     #0x1F             // get back to SVC mode to execute the handler in SVC mode
    sub     r4, lr, #4      // get the address of the raising instruction

    bl      __exception_handler_default
    b       __hang          // this exception type is not recoverable, savely hang here

__floating_point_ex:
	bic		r0, r0, #0x80000000
	fmxr	fpexc, r0		// clear EX bit

	restore_state_return    // return from this exception


__software_interrupt_trampoline:
    sub     lr, lr, #4      // get the real exception return address
    save_state
    mov     r0, #EXC_SOFTWARE_INTERRUPT
    mrs     r1, spsr        // get SPSR
    mov     r2, sp
    mov     r3, lr
	
    bl      __exception_handler_default
	
    restore_state_return    // return from this exception

__prefetch_abort_trampoline:
    mov     r0, #EXC_PREFETCH_ABORT
    mrs     r1, spsr
    cps		#0x12			// switch to IRQ mode to access sp_irq and lr_irq
	mov		r2, sp			// store IRQ mode stack pointer
	mov		r3, lr			// store IRQ mode return address
	cps		#0x1F			// switch to system mode for the handler to be run
    bl      __exception_handler_default
    b       __hang         // this exception is not recoverable, hang here

__data_abort_trampoline:
    mov     r0, #EXC_DATA_ABORT
    mrs     r1, spsr
    cps		#0x12			// switch to IRQ mode to access sp_irq and lr_irq
	mov		r2, sp			// store IRQ mode stack pointer
	mov		r3, lr			// store IRQ mode return address
	cps		#0x1F			// switch to system mode for the handler to be run
    bl      __exception_handler_default
    b       __hang         // this exception is not recoverable, hang here

__unused_trampoline:
    b       __hang          // hang safely here

__interrupt_trampoline:
    sub     lr, lr, #4  // calculate the real return address from this exception
    save_state
    mov     r0, #EXC_IRQ
    mrs     r1, spsr        // get SPSR
    mov     r2, sp
    mov     r3, lr
	
    bl      __exception_handler_default

	restore_state_return    // return from this exception

__fast_interrupt_trampoline:
    sub     lr, lr, #4  // calculate the real return address from this exception
    save_state
    mov     r0, #EXC_FIQ
    mrs     r1, spsr        // get SPSR
    mov     r2, sp
    mov     r3, lr
	sub     r4, lr, #4

    bl      __exception_handler_default

	restore_state_return    // return from this exception