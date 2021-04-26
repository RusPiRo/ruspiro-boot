//! # Minimal example that should compile
//!

#![no_std]
#![no_main]

#[macro_use]
extern crate ruspiro_boot;

come_alive_with!(alive);
run_with!(running);

fn alive(_core: u32) {
    // do one-time initialization here
}

fn running(_core: u32) -> ! {
    // do any processing here and ensure you never return from this function
    loop {}
}
