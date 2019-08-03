/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/
//! Build script to pre-compile the assembly files containing the majority of the boot up and initial configuration
//! code
//! 

extern crate cc;
use std::env;

fn main() {
    let build_pi3 = env::var_os("CARGO_FEATURE_RUSPIRO_PI3").is_some();
    if build_pi3 {
        cc::Build::new()
            .file("src/asm/boot.s")
            .compile("boot");

        cc::Build::new()
            .file("src/asm/irqtrampoline.s")
            .compile("irqtrampoline");
        
        cc::Build::new()
            .file("src/asm/mmu.s")
            .compile("mmu");
    }
}