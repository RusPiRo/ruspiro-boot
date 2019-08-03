/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/

//! # Default exception handler implementation
//! 
//! This module provides empty default exception and interrupt handlers that are required by the linker script to be
//! available as long as the user of this crate does not provide his own exception and interrupt handling.
//! However, having an default empty interrupt handler could cause endless interrupt loops as the appearing IRQ's will
//! never beeing aknowledged this implementation just globally deactivates the interrupts.

#[allow(non_snake_case)]
#[no_mangle]
fn __exception_handler_Default() -> ! {    
    // the exception handler should never return
    loop { }
}

#[allow(non_snake_case)]
#[no_mangle]
fn __interrupt_handler_Default() {
    // deactivate global interrupts as empty handling may cause endless IRQ loops
    #[cfg(feature="ruspiro_pi3")]
    unsafe { asm!("cpsid i") };
}
