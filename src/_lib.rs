/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.3.0")]
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
//! be linked with the linker script corresponding to the build target:
//! [aarch32 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.0/link32.ld)
//! [aarch64 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.0/link64.ld)
//! 
//! The binary would not need any further dependencies to compile and link into a kernel image file that could be put
//! onto a Raspberry Pi SD card and executed as baremetal kernel.
//! 
//! # Features
//! 
//! - ``ruspiro_pi3`` is active by default and need not to be passed. This ensures proper building of the boot assembly.
//! - ``with_panic`` will ensure that a default panic handler is implemented.
//! - ``with_exception`` will ensure that a default exception and interrupt handler is implemented.
//! - ``singlecore`` enforces the compilition of the single core boot sequence. Only the main core 0 is then running.
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

/********** DEVICE TESTING ONLY *******************************/
#[no_mangle]
extern "C" fn lit_led(num: u32) {
    let fsel_num = num / 10;
    let fsel_shift = (num % 10)*3;
    let fsel_addr = 0x3f20_0000 + 4*fsel_num;
    let set_addr = 0x3f20_001c + num/32;
    let mut fsel: u32 = unsafe { core::ptr::read_volatile(fsel_addr as *const u32) };
    fsel &= !(7 << fsel_shift);
    fsel |= 1 << fsel_shift;
    unsafe { core::ptr::write_volatile(fsel_addr as *mut u32, fsel) };

    let set: u32 = 1 << (num & 0x1F);
    unsafe { core::ptr::write_volatile(set_addr as *mut u32, set) };
}

use ruspiro_uart::Uart1;
static mut UART: Uart1 = Uart1::new();

#[no_mangle]
unsafe extern "C" fn init_uart() {
    let _ = UART.initialize(250_000_000, 115_200);
}

#[no_mangle]
unsafe extern "C" fn dump_hex(value: u64) {
    const HEXCHAR : &[u8] = "0123456789ABCDEF".as_bytes();
    let mut tmp = value;
    let mut hex: [u8;32] = [0; 32];
    let mut idx = 0;
    while (tmp != 0) {
        //UART.send_char(HEXCHAR[(tmp & 0xF) as usize] as char);
        hex[idx] = HEXCHAR[(tmp & 0xF) as usize];
        tmp = tmp >> 4;
        idx = idx+1;
    }

    UART.send_string("\r\n0x");
    for i in 0..32 {
        if hex[31-i] != 0 {
            UART.send_char(hex[31-i] as char);
        }
    }    
}