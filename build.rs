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
    let script_location = env::current_dir().unwrap();
    println!("cargo:linkerscript={}\\link64.ld", script_location.display());
    
    match env::var_os("CARGO_CFG_TARGET_ARCH") {
        Some(target_arch) => {
            if env::var_os("CARGO_FEATURE_RUSPIRO_PI3").is_some() {
                /*
                if target_arch == "arm" {
                    cc::Build::new()
                        .file("src/asm/aarch32/boot.s")
                        .flag("-march=armv8-a")
                        .flag("-mfpu=neon-fp-armv8")
                        .flag("-mfloat-abi=hard")
                        .compile("boot");

                    // allow to choose: boot only single core 0 or all 4 cores ?
                    // the boot code differs a small bit...
                    let build_singlecore = env::var_os("CARGO_FEATURE_SINGLECORE").is_some();
                    if build_singlecore {
                        cc::Build::new()
                            .file("src/asm/aarch32/run_single.s")
                            .flag("-march=armv8-a")
                            .flag("-mfpu=neon-fp-armv8")
                            .flag("-mfloat-abi=hard")
                            .compile("runsingle");
                    } else {
                        cc::Build::new()
                            .file("src/asm/aarch32/run_multi.s")
                            .flag("-march=armv8-a")
                            .flag("-mfpu=neon-fp-armv8")
                            .flag("-mfloat-abi=hard")
                            .compile("runmulti");
                    }

                    cc::Build::new()
                        .file("src/asm/aarch32/irqtrampoline.s")
                        .flag("-march=armv8-a")
                        .flag("-mfpu=neon-fp-armv8")
                        .flag("-mfloat-abi=hard")
                        .compile("irqtrampoline");
                    
                    cc::Build::new()
                        .file("src/asm/aarch32/mmu.s")
                        .flag("-march=armv8-a")
                        .flag("-mfpu=neon-fp-armv8")
                        .flag("-mfloat-abi=hard")
                        .compile("mmu");
                }
                */

                if target_arch == "aarch64" {
                    cc::Build::new()
                        .file("src/asm/aarch64/bootstrap.S")
                        .flag("-march=armv8-a")
                        .compile("bootstrap");
                    cc::Build::new()
                        .file("src/asm/aarch64/exceptionvector.S")
                        .flag("-march=armv8-a")
                        .compile("excvector");

/*                        
                    cc::Build::new()
                        .file("src/asm/aarch64/boot.s")
                        .flag("-march=armv8-a")
                        .compile("boot");

                    // allow to choose: boot only single core 0 or all 4 cores ?
                    // the boot code differs a small bit...
                    let build_singlecore = env::var_os("CARGO_FEATURE_SINGLECORE").is_some();
                    if build_singlecore {
                        cc::Build::new()
                            .file("src/asm/aarch64/run_single.S")
                            .flag("-march=armv8-a")
                            .compile("runsingle");
                    } else {
                        cc::Build::new()
                            .file("src/asm/aarch64/run_multi.S")
                            .flag("-march=armv8-a")
                            .compile("runmulti");
                    }

                    cc::Build::new()
                        .file("src/asm/aarch64/mmu.S")
                        .flag("-march=armv8-a")
                        .compile("mmu");

                    cc::Build::new()
                        .file("src/asm/aarch64/irqtrampoline.S")
                        .flag("-march=armv8-a")
                        .compile("irqtrampoline");
                */
                }
            }
        }
        _ => ()
    }
}