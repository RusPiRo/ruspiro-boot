/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: ???
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.3.0")]
#![no_std]
#![feature(asm, lang_items)]

//! # RusPiRo Boot Strapping
//! 

pub mod macros;
pub use self::macros::*;

#[cfg(target_arch="aarch64")]
mod mmu64;
#[cfg(target_arch="aarch64")]
use mmu64 as mmu;

mod exceptionlevel;

mod panic;

use ruspiro_interrupt::IRQ_MANAGER;
use ruspiro_uart::Uart1;

/// Entry point that is called by the bootstrapping code.
/// From here we will branch into the kernel code provided by the user of this crate.
/// To conviniently provide those entry points the crate user should use the respective macros
/// `come_alive_with!` and `run_with!`
///
#[export_name = "__rust_entry"]
fn __rust_entry(core: u32) -> ! {
    // entering here we are typically in EL2, a kernel shall always run at EL1. So perform
    // the exception level switch to EL1 by properly return from EL2
    exceptionlevel::switch_to_el1();

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
        uart.send_string("########## RusPiRo ---------- Bootstrapper v0.3 ---------- ##########\r\n");

        // now initialize the interrupt manager
        IRQ_MANAGER.take_for(|irq_mgr| irq_mgr.initialize());
    }

    // now follows the configuration that is needed to be done by all cores

    // now that the initialization was done we can jump into the "application"
    // specific initialization
    extern "C" { fn __kernel_startup(core: u32); }
    unsafe { __kernel_startup(core); }

    // once the one-time startup of this core has been done kickoff any other core
    #[cfg(not(feature="singlecore"))]
    kickoff_next_core(core);


    // after the one time setup of the "application" enter the processing loop
    extern "C" { fn __kernel_run(core: u32) -> !; }
    unsafe { __kernel_run(core); }
}

#[cfg(target_arch="aarch64")]
fn kickoff_next_core(core: u32) {
    extern "C" { fn __boot(); }
    // kicking of another core in arch64 means, writing the jump address for this
    // core into a specific memory location
    let jump_store: u64 = match core {
        0 => 0xe0,
        1 => 0xe8,
        2 => 0xf0,
        _ => return
    };
    unsafe {
        core::ptr::write_volatile(jump_store as *mut u64, __boot as *const () as u64);
        asm!("sev"); // trigger an event to wake up the sleeping cores
    }
}
