/***********************************************************************************************************************
 * Initial setup for the Interrupt trampoline functions that will branch into rust environment
 * in case the corresponding Exception/Interrupt is raised
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/

.global __exception_handler_Default
.global __interrupt_handler_Default

 /****************************************************
  * quite a convinient way to define the IRQ table entries as
  * jump addresses to the respective IRQ trampolines
  ****************************************************/
 .align 4
 __irq_trampolines:
    ldr 	pc, __reset_trampoline_addr
    ldr 	pc, __undefined_instruction_trampoline_addr
    ldr 	pc, __software_interrupt_trampoline_addr
    ldr 	pc, __prefetch_abort_trampoline_addr
    ldr 	pc, __data_abort_trampoline_addr
    ldr 	pc, __unused_tranpoline_addr
    ldr 	pc, __interrupt_trampoline_addr
    ldr 	pc, __fast_interrupt_trampoline_addr

// now the trampoline place holders:
__reset_trampoline_addr:                     .word   __reset_trampoline
__undefined_instruction_trampoline_addr:     .word   __undefined_instruction_trampoline
__software_interrupt_trampoline_addr:        .word   __software_interrupt_trampoline
__prefetch_abort_trampoline_addr:            .word   __prefetch_abort_trampoline
__data_abort_trampoline_addr:                .word   __data_abort_trampoline
__unused_tranpoline_addr:                    .word   __unused_tranpoline
__interrupt_trampoline_addr:                 .word   __interrupt_trampoline
__fast_interrupt_trampoline_addr:            .word   __fast_interrupt_trampoline

/**********************************************************************
 * implementation of the trampolines
 **********************************************************************/
__irq_hang:
    b   __irq_hang

__reset_trampoline:
    b   __irq_hang

__undefined_instruction_trampoline:
    stmfd	sp!, {r0, lr}	// store register
	fmrx	r0, fpexc		// check for floating point exception as this is recoverable
	tst		r0, #0x80000000	// EX bit set in FPEXC?
	bne		__floating_point_ex

	sub		lr, lr, #4		// calculate correct address of aborted program
	stmfd	sp!, {lr}		// store lr on stack
	mrs		lr, spsr		// get SPSR
	stmfd	sp!, {lr}		// and put it onto stack
	stmfd	sp, {r0-r14}^	// store un banked registers
	sub		sp, sp, #4*15	// adjust stack pointer as it is not done by previous call
	mov		r1, sp			// keep current stack pointer
	cps		#0x12			// switch to IRQ mode to access sp_irq and lr_irq
	mov		r2, sp			// store IRQ mode stack pointer
	mov		r3, lr			// store IRQ mode return address
	cps		#0x1F			// switch to system mode for the handler to be run
	mov		sp, r1			// set this stack pointer to be the initial mode stack pointer when IRQ has been entered
	stmfd	sp!, {r2, r3}	// store the IRQ SP and IRQ LR on the stack
	mov		r0, sp			// store current stack pointer to pass to the handler
	b		__undefined_instruction_h	// call the handler without returning
    b       __irq_hang          // if it returns - hang safely here

__floating_point_ex:
	bic		r0, r0, #0x80000000
	fmxr	fpexc, r0		// clear EX bit
	ldmfd	sp!, {r0, pc}^	// return to caller


__software_interrupt_trampoline:
    sub		lr, lr, #4			// get the real return address from the IRQ
	stmfd	sp!, {r0-r12, lr}	// save all un-banked registers to the stack
	bl		__software_interrupt_h		// call the handler
	ldmfd	sp!, {r0-r12, pc}^	// restore registers and return

__prefetch_abort_trampoline:
    sub		lr, lr, #4		// calculate correct address of aborted program
	stmfd	sp!, {lr}		// store lr on stack
	mrs		lr, spsr		// get SPSR
	stmfd	sp!, {lr}		// and put it onto stack
	stmfd	sp, {r0-r14}^	// store un banked registers
	sub		sp, sp, #4*15	// adjust stack pointer as it is not doe by previous call
	mov		r1, sp			// keep current stack pointer
	cps		#0x12			// switch to IRQ mode to access sp_irq and lr_irq
	mov		r2, sp			// store IRQ mode stack pointer
	mov		r3, lr			// store IRQ mode return address
	cps		#0x1F			// switch to system mode for the handler to be run
	mov		sp, r1			// set this stack pointer to be the initial mode stack pointer when IRQ has been entered
	stmfd	sp!, {r2, r3}	// store the IRQ SP and IRQ LR on the stack
	mov		r0, sp			// store current stack pointer to pass to the handler
	b		__prefetch_abort_h	// call the handler without returning
    b       __irq_hang          // if it returns - hang safely here

__data_abort_trampoline:
    sub		lr, lr, #8		// calculate correct address of aborted program
	stmfd	sp!, {lr}		// store lr on stack
	mrs		lr, spsr		// get SPSR
	stmfd	sp!, {lr}		// and put it onto stack
	stmfd	sp, {r0-r14}^	// store un backed registers
	sub		sp, sp, #4*15	// adjust stack pointer as it is not doe by previous call
	mov		r1, sp			// keep current stack pointer
	cps		#0x12			// switch to IRQ mode to access sp_irq and lr_irq
	mov		r2, sp			// store IRQ mode stack pointer
	mov		r3, lr			// store IRQ mode return address
	cps		#0x1F			// switch to system mode for the handler to be run
	mov		sp, r1			// set this stack pointer to be the initial mode stack pointer when IRQ has been entered
	stmfd	sp!, {r2, r3}	// store the IRQ SP and IRQ LR on the stack
	mov		r0, sp			// store current stack pointer to pass to the handler
	b		__data_abort_h	// call the handler without returning
    b       __irq_hang          // if it returns - hang safely here

__unused_tranpoline:
    b       __irq_hang          // hang safely here

__interrupt_trampoline:
    sub		lr, lr, #4			// get the real return address from the IRQ
	stmfd	sp!, {r0-r12, lr}	// save all un-banked registers to the stack	
	mrc		p15, 0, r0, c0, c0, 5
	and		r0, r0, #3			// mask the CPU id in bit's 0:1
	bl		__interrupt_h		// call the handler

	ldmfd	sp!, {r0-r12, pc}^	// restore registers and return

__fast_interrupt_trampoline:
    sub		lr, lr, #4				// get the real return address from the IRQ
	stmfd	sp!, {r0-r7, lr}		// save all un-banked registers to the stack
	bl		__fast_interrupt_h	// call the handler

	ldmfd	sp!, {r0-r7, pc}^		// restore registers and return


.ltorg:
__hack_1: .word __exception_handler_Default
__hack_2: .word __interrupt_handler_Default
