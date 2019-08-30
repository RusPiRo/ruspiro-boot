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
    match env::var_os("CARGO_CFG_TARGET_ARCH") {
        Some(target_arch) => {
            if target_arch == "arm" && env::var_os("CARGO_FEATURE_RUSPIRO_PI3").is_some() {
                cc::Build::new()
                    .file("src/asm/boot.s")
                    .flag("-march=armv8-a")
                    .flag("-mfpu=neon-fp-armv8")
                    .flag("-mfloat-abi=hard")
                    .compile("boot");

                // allow to choose: boot only single core 0 or all 4 cores ?
                // the boot code differs a small bit...
                let build_singlecore = env::var_os("CARGO_FEATURE_SINGLECORE").is_some();
                if build_singlecore {
                    cc::Build::new()
                        .file("src/asm/run_single.s")
                        .flag("-march=armv8-a")
                        .flag("-mfpu=neon-fp-armv8")
                        .flag("-mfloat-abi=hard")
                        .compile("runsingle");
                } else {
                    cc::Build::new()
                        .file("src/asm/run_multi.s")
                        .flag("-march=armv8-a")
                        .flag("-mfpu=neon-fp-armv8")
                        .flag("-mfloat-abi=hard")
                        .compile("runmulti");
                }

                cc::Build::new()
                    .file("src/asm/irqtrampoline.s")
                    .flag("-march=armv8-a")
                    .flag("-mfpu=neon-fp-armv8")
                    .flag("-mfloat-abi=hard")
                    .compile("irqtrampoline");
                
                cc::Build::new()
                    .file("src/asm/mmu.s")
                    .flag("-march=armv8-a")
                    .flag("-mfpu=neon-fp-armv8")
                    .flag("-mfloat-abi=hard")
                    .compile("mmu");
            }
        }
        _ => ()
    }
}