/***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann <pspwizard@gmx.de>
 * License: Apache License 2.0 / MIT
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/||VERSION||")]
#![no_std]
#![feature(llvm_asm, lang_items, linkage)]
// this crate does only compile with valid content if the target architecture is AARCH64!
#![cfg(target_arch = "aarch64")]

//! # RusPiRo Bootstrapping for Raspberry Pi
//!
//! This crates provides the startup routines that are needed to be run from a baremetal kernel on
//! the RaspberryPi before execution could be handed over to Rust code.
//! 
//! The crate is only valid when compiled for the
//! target architecture **aarch64**. However, event though this crate might be compiled for this target architecture it
//! is tailor made for the Raspberry Pi 3. This crate may be used in other contexts at your own risk. To build your own
//! Raspberry Pi bare metal kernel or operating system please use the
//! [RusPiRo Turorials](https://github.com/RusPiRo/ruspiro-tutorials) as a starting point.
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
//! # Features
//!
//! Feature         | Description
//! ----------------|------------------------------------------------------------------------------
//! ``multicore``   | Enables the compilation of the multi core boot sequence. Without it only the main core 0 is running.
//!
//! ## Hint:
//! To successfully build a bare metal binary/kernel that depends on this one to perform the boot
//! strapping part it is **highly recomended** to use the linker script [link64.ld](https://github.com/RusPiRo/ruspiro-boot/blob/v||VERSION||/link64.ld) provided by this crate.
//! To conviniently refer to the linker scripts contained in this crate it's recommended to use a
//! specific build script in your project that copies the required file to your current project
//! folder and could then be referred to with the `RUSTFLAG` parameter `-C link-arg=-T./link64.ld`.
//! The build script is a simple `build.rs` rust file in your project root with the following
//! contents:
//!
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

mod exception;
pub mod macros;

pub use self::macros::*;
use ruspiro_cache as cache;

// TODO: verify if the stubs are really required
//#[cfg(not(any(test, doctest)))]
//mod stubs;

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
unsafe fn __rust_entry(core: u32) -> ! {
  // first step before going any further is to clean the L1 cache to ensure there
  // is no garbage remaining that could impact actual execution once the cache is enabled.
  cache::invalidate_dcache();

  // jump to the function provided by the user of this crate
  #[cfg(not(test))]
  __kernel_startup(core);

  // once the one-time startup of this core has been done kickoff any other core
  #[cfg(feature = "multicore")]
  kickoff_next_core(core);

  // after the one time setup enter the processing loop
  #[cfg(not(test))]
  __kernel_run(core);

  #[cfg(test)]
  loop {}
}

#[cfg(feature = "multicore")]
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
    ptr::write_volatile(jump_store as *mut u64, 0x80000); //__boot as *const () as u64);
                                                          // as this core may have caches enabled, flush it so the other core
                                                          // sees the correct data on memory and the write does not only hit the cache
    cache::flush_dcache_range(0xe0, 0x10);
    llvm_asm!("sev"); // trigger an event to wake up the sleeping cores
  }
}
