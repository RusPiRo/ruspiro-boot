/***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/

//! # Panic Handler
//!
//! Minimalistic panic handler implementation
//!

use core::panic::PanicInfo;
use log::error;

#[cfg(all(not(test), feature = "panic"))]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
  // Panicing means we have reach a situation we are unable to recover from into a valid state.
  // Halt the panicing core and safely do nothing!
  // The error will be printed using the log crate. It requires a global logger to be configured
  // otherwise the output is just going no-where. Refer to the ruspiro-console crate which provides
  // the functionality to setup a global logger
  error!("PANIC: {}", info);
  loop {}
}

#[lang = "eh_personality"]
fn eh_personality() {
  // for the time beeing - nothing to be done in this function as the usecase is a bit unclear
}
