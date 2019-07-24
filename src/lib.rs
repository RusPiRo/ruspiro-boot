/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: ???
 **********************************************************************************************************************/
#![doc(html_root_url = "https://docs.rs/ruspiro-boot/0.0.1")]
#![no_std]
#![feature(asm)]        // needed to be able to use inline assembly
#![feature(global_asm)] // needed to include and compile external assembly files

//! # RusPiRo Boot crate
//! This crates provides the startup routines that will be run from a baremetal kernel on the RaspberryPi.
//! 

// including the assembly files
global_asm!(include_str!("./asm/boot.s"));
global_asm!(include_str!("./asm/mmu.s"));
global_asm!(include_str!("./asm/irqtrampoline.s"));
