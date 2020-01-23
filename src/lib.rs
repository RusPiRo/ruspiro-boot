/***********************************************************************************************************************
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.3.1")]
#![cfg_attr(not(any(test, doctest)), no_std)]
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
//! [aarch32 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.1/link32.ld)
//! [aarch64 linker script](https://github.com/RusPiRo/ruspiro-boot/blob/v0.3.1/link64.ld)
//!
//! # Features
//!
//! - `with_panic` will ensure that a default panic handler is implemented.
//! - `singlecore` enforces the compilation of the single core boot sequence. Only the main core 0 is then running.
//! - `ruspiro_pi3` is passed to dependent crates to properly build them for the desired Raspberry Pi version
//!
//! To successfully build a bare metal binary using this crate for the boot strapping part it is
//! **highly recomended** to use the linker script provided by this crate. Based on the target
//! architecture to be built it is either [link32.ld](link32.ld) or [link64.ld](link64.ld). To
//! conviniently refer to the linker scripts contained in this crate it's recommended to use a
//! specific build script in your project that copies the required file to your current project
//! folder and could then be referred to with the `RUSTFLAG` parameter `-C link-arg=-T./link<aarch>.ld`.
//! The build script is a simple `build.rs` rust file in your project root with the following
//! contents:
//! ```no_run
//! use std::{env, fs, path::Path};
//!
//! fn main() {
//!     // copy the linker script from the boot crate to the current directory
//!     // so it will be invoked by the linker
//!     let ld_source = env::var_os("DEP_RUSPIRO_BOOT_LINKERSCRIPT")
//!         .expect("error in ruspiro build, `ruspiro-boot` not a dependency?")
//!         .to_str()
//!         .unwrap()
//!         .replace("\\", "/");;
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
//!
//! To get started you could check out the template projects [here](https://www.github.com/RusPiRo/ruspiro_templates)
//!

pub mod macros;
pub use self::macros::*;

#[cfg_attr(target_arch = "aarch64", path = "mmu64.rs")]
#[cfg_attr(target_arch = "arm", path = "mmu32.rs")]
mod mmu;

#[cfg(not(any(test, doctest)))]
mod panic;
#[cfg(not(any(test, doctest)))]
mod stubs;

#[cfg(all(target_arch = "aarch64", not(feature = "singlecore")))]
use ruspiro_cache as cache;

use ruspiro_console::*;
use ruspiro_mailbox::*;
use ruspiro_timer as timer;
use ruspiro_uart::Uart1;
use ruspiro_interrupt::IRQ_MANAGER;

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
    #[cfg(any(target_arch = "arm", target_arch = "aarch64"))]
    mmu::initialize_mmu(core);
    // special additional setup might be done on the main core only
    if core == 0 {
        // get the current core clock rate to initialize the Uart1 with
        let core_rate = MAILBOX
            .take_for(|mb: &mut Mailbox| mb.get_clockrate(ClockId::Core))
            .unwrap_or(250_000_000);
        // first thing we would like to do is to let the outside world know that we are booting
        // so if this is core 0 we initialze the uart1 interface with default settings and print some
        // string
        let mut uart = Uart1::new();

        let _ = uart.initialize(core_rate, 115_200);
        CONSOLE.take_for(|console| console.replace(uart));

        #[cfg(target_arch = "aarch64")]
        println!("\r\n########## RusPiRo ----- Bootstrapper v0.3 @ Aarch64 ----- ##########");
        #[cfg(target_arch = "arm")]
        println!("\r\n########## RusPiRo ----- Bootstrapper v0.3 @ Aarch32 ----- ##########");

        // do some arbitrary sleep here to let the uart send the initial greetings before running
        // the kernel, which may initialize the UART for it's own purpose and this would break
        // this transfer...
        timer::sleep(10000);

        // configure interrupt manager for further usage
        IRQ_MANAGER.take_for(|mgr| mgr.initialize());
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
