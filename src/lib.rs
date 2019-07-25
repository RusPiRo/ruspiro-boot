/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.0.1")]
#![no_std]
#![feature(asm)]        // needed to be able to use inline assembly
#![feature(global_asm)] // needed to include and compile external assembly files
#![feature(lang_items)]

//! # RusPiRo Boot crate
//! This crates provides the startup routines that will be run from a baremetal kernel on the RaspberryPi.
//!
//! 

// if we do activiate the feature "with_panic" the boot crate will provide default panic handler that does
// hang the panicing core
#[cfg(feature = "with_panic")]
mod panic;

#[cfg(feature = "with_exception")]
mod exception;

// including the assembly files
global_asm!(include_str!("./asm/boot.s"));
global_asm!(include_str!("./asm/mmu.s"));
global_asm!(include_str!("./asm/irqtrampoline.s"));
