/***********************************************************************************************************************
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.3.0")]
#![no_std]
#![feature(asm, lang_items, linkage)]

//! # RusPiRo Boot Strapping for Raspberry Pi
//!
//! This crates provides the startup routines that are needed to be run from a baremetal kernel on
//! the RaspberryPi before execution could be handed over to Rust code.
//!
//! # Usage
//!
//! Put the following code into your main rustfile of the binary that should be build for the
//! Raspberry Pi:
//! ```ignore
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
//!     // do any processing here and ensure you never return from this function
//!     loop {}
//! }
//! ```
//!
//! The bootstrapper requires specific symbols to be known to the linker to be able to build the
//! final binary. To use the linker script that is provided as part of this crate in
//! your own rust binary crate you could either copy them manually from the git repository based on
//! your desired target architecture for the build:
//! [aarch32 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.0/link32.ld)
//! [aarch64 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.0/link64.ld)
//!
//! The **recommanded** way would be to use a build script that copies the linker script from this
//! crate into your current crates directory to be used for linking. To do soe create a ``build.rs``
//! file in your projects root folder with the following contents:
//! ```no_run
//! use std::{env, fs, path::Path};
//!
//! fn main() {
//!     // copy the linker script from the boot crate to the current directory
//!     // so it will be invoked by the linker
//!     let ld_source = env::var_os("DEP_RUSPIRO_BOOT_LINKERSCRIPT")
//!         .expect("error in ruspiro build, `ruspiro-boot` not a dependency?");
//!     let src_file = Path::new(&ld_source);
//!     let trg_file = format!(
//!         "{}/{}",
//!         env::current_dir().unwrap().display(),
//!         src_file.file_name().unwrap().to_str().unwrap()
//!     );
//!     println!("Copy linker script from {:?}, to {:?}", src_file, trg_file);
//!     fs::copy(src_file, trg_file).unwrap();
//! }
//! ```
//! As the boot routines provided by this crate depend on some external defined linker symbols the binary should always
//! be linked with the linker script corresponding to the build target:
//! # Features
//!
//! - ``with_panic`` will ensure that a default panic handler is implemented.
//! - ``with_exception`` will ensure that a default exception and interrupt handler is implemented.
//! - ``singlecore`` enforces the compilation of the single core boot sequence. Only the main core 0 is then running.
//!

pub mod macros;
pub use self::macros::*;

#[cfg_attr(target_arch = "aarch64", path = "mmu64.rs")]
#[cfg_attr(target_arch = "arm", path = "mmu32.rs")]
#[cfg_attr(
    not(all(target_arch = "arm", target_arch = "aarch64")),
    path = "mmuxx.rs"
)]
mod mmu;

#[cfg(not(test))]
mod panic;
#[cfg(not(test))]
mod stubs;

#[cfg(any(target_arch = "arm", target_arch = "aarch64"))]
use ruspiro_cache as cache;
use ruspiro_interrupt::IRQ_MANAGER;
use ruspiro_timer as timer;
use ruspiro_uart::Uart1;

extern "C" {
    fn __kernel_startup(core: u32);
    fn __kernel_run(core: u32) -> !;
    fn __boot();
}

/// Entry point that is called by the bootstrapping code.
/// From here we will branch into the kernel code provided by the user of this crate.
/// To conviniently provide those entry points the crate user should use the respective macros
/// `come_alive_with!` and `run_with!`. This entry point is assumed to be always called
/// in EL1(aarch64) or SVC(aarch32) mode
///
#[export_name = "__rust_entry"]
fn __rust_entry(core: u32) -> ! {
    // very first thing is to setup the MMU which allows us to
    // use atomic operations in the upcomming initialization
    mmu::initialize_mmu(core);

    // special additional setup might be done on the main core only
    if core == 0 {
        // first thing we would like to do is to let the outside world know that we are booting
        // so if this is core 0 we initialze the uart1 interface with default settings and print some
        // string
        let mut uart = Uart1::new();

        let _ = uart.initialize(250_000_000, 115_200);

        #[cfg(target_arch = "aarch64")]
        uart.send_string(
            "\r\n########## RusPiRo ----- Bootstrapper v0.3 @ Aarch64 ----- ##########\r\n",
        );
        #[cfg(target_arch = "arm")]
        uart.send_string(
            "\r\n########## RusPiRo ----- Bootstrapper v0.3 @ Aarch32 ----- ##########\r\n",
        );

        // do some arbitrary sleep here to let the uart send the initial greetings before running
        // the kernel, which may initialize the UART for it's own purpose and this would break
        // this transfer...
        timer::sleep(10000);

        // now initialize the interrupt manager
        IRQ_MANAGER.take_for(|irq_mgr| irq_mgr.initialize());
    }

    // now follows the configuration that is needed to be done by all cores
    // TODO: is there something we need to prepare ?

    // now that the initialization was done we can jump into the "application"
    // specific initialization
    #[cfg(not(test))]
    unsafe {
        __kernel_startup(core)
    }

    // once the one-time startup of this core has been done kickoff any other core
    #[cfg(all(
        any(target_arch = "arm", target_arch = "aarch64"),
        not(feature = "singlecore")
    ))]
    kickoff_next_core(core);

    // after the one time setup of the "application" enter the processing loop
    #[cfg(not(test))]
    unsafe {
        __kernel_run(core)
    }

    #[cfg(test)]
    loop {}
}

#[cfg(all(target_arch = "arm", not(feature = "singlecore")))]
fn kickoff_next_core(core: u32) {
    // kicking of another core in arch32 means, writing the jump address for this
    // core into it's specific mailbox
    let jump_store: u64 = match core {
        0 => 0x4000_009C, // write start address to core 1 mailbox 3
        1 => 0x4000_00AC, // write start address to core 2 mailbox 3
        2 => 0x4000_00BC, // write start address to core 3 mailbox 3
        _ => return,
    };
    unsafe {
        core::ptr::write_volatile(jump_store as *mut u32, __boot as *const () as u32);
        asm!("sev"); // trigger an event to wake up the sleeping cores
    }
}

#[cfg(all(target_arch = "aarch64", not(feature = "singlecore")))]
fn kickoff_next_core(core: u32) {
    // kicking of another core in arch64 means, writing the jump address for this
    // core into a specific memory location
    let jump_store: u64 = match core {
        0 => 0xe0,
        1 => 0xe8,
        2 => 0xf0,
        _ => return,
    };
    unsafe {
        core::ptr::write_volatile(jump_store as *mut u64, 0x80000); //__boot as *const () as u64);
                                                                    // as this core may have caches enabled, clean/invalidate so the other core
                                                                    // sees the correct data on memory and the write does not only hit the cache
        cache::cleaninvalidate();
        asm!("sev"); // trigger an event to wake up the sleeping cores
    }
}
