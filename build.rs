/***************************************************************************************************
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **************************************************************************************************/
//! Build script to pre-compile the assembly files containing the majority of the bootstrap code
//! and some initial configuration required before rust code could pick up processing
//!

extern crate cc;
use std::env;

fn main() {
    let script_location = env::current_dir().unwrap();

    if let Some(target_arch) = env::var_os("CARGO_CFG_TARGET_ARCH") {
        if target_arch == "arm" {
            cc::Build::new()
                .file("src/asm/aarch32/bootstrap.S")
                .flag("-march=armv8-a")
                .compile("bootstrap");
            cc::Build::new()
                .file("src/asm/aarch32/exceptionvector.S")
                .flag("-march=armv8-a")
                .compile("excvector");
            // print the linker file location of the boot crate to the env-variables
            println!("cargo:linkerscript={}/link32.ld", script_location.display());

            println!("cargo:rerun-if-changed=link32.ld");
            println!("cargo:rerun-if-changed=src/asm/aarch32/bootstrap.S");
            println!("cargo:rerun-if-changed=src/asm/aarch32/exceptionvector.S");
        }

        if target_arch == "aarch64" {
            cc::Build::new()
                .file("src/asm/aarch64/bootstrap.S")
                .flag("-march=armv8-a")
                .compile("bootstrap");
            cc::Build::new()
                .file("src/asm/aarch64/exceptionvector.S")
                .flag("-march=armv8-a")
                .compile("excvector");
            // print the linker file location of the boot crate to the env-variables
            println!("cargo:linkerscript={}/link64.ld", script_location.display());

            println!("cargo:rerun-if-changed=link64.ld");
            println!("cargo:rerun-if-changed=src/asm/aarch64/bootstrap.S");
            println!("cargo:rerun-if-changed=src/asm/aarch64/exceptionvector.S");
        }
    }
}
