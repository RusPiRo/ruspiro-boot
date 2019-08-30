/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.2.0")]
#![no_std]
#![feature(asm)]
#![feature(lang_items)]

//! # RusPiRo Boot for Raspberry Pi 3
//! This crates provides the startup routines that will be run from a baremetal kernel on the RaspberryPi.
//! 
//! # Usage
//! 
//! Put the following code into your main rustfile of the binary that should be build for the Raspberry Pi:
//! ```
//! #[macro_use]
//! extern crate ruspiro_boot;
//! 
//! come_alive_with!(alive);
//! run_with!(running);
//! 
//! fn alive(core: u32) {
//!     // do one-time initialization here
//! }
//! 
//! fn running(core: u32) -> ! {
//!     loop {
//!         // do any processing here and ensure you never return from this function
//!     }
//! }
//! ```
//! As the boot routines provided by this crate depend on some external defined linker symbols the binary should always
//! be linked with this [linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.2.0/link.ld)
//! 
//! The binary would not need any further dependencies to compile and link into a kernel image file that could be put
//! onto a Raspberry Pi SD card and executed as baremetal kernel.
//! 
//! # Features
//! 
//! - ``ruspiro_pi3`` is active by default and need not to be passed. This ensures proper building of the boot assembly.
//! - ``with_panic`` will ensure that a default panic handler is implemented.
//! - ``with_exception`` will ensure that a default exception and interrupt handler is implemented.
//! 


pub mod macros;
pub use self::macros::*;

// if we do activiate the feature "with_panic" the boot crate will provide default panic handler that does
// hang the panicing core
#[cfg(feature = "with_panic")]
mod panic;

#[cfg(feature = "with_exception")]
mod exception;

// incorporate the stubs needed by the linker
mod stubs;
