/***********************************************************************************************************************
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/

//! # Default panic handler implementation
//!
//! This module provides panic handler and personality function for a baremetal kernel that does not provide his own.
//! It will be compiled into if the feature "with_panic" is active

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    // Panicing is undefined behaviour so we are unable to recover from one into a valid state.
    // Halt the panicing core and safely do nothing!
    loop {}
}

#[lang = "eh_personality"]
fn eh_personality() {
    // for the time beeing - nothing to be done as the usecase is a bit unclear
}
