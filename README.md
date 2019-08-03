# Boot crate for the RusPiRo kernel

This crate provides basic boot code that - when build into a kernel crate - will be executed as soon as the Raspberry Pi powers up. As the building of this crate and finally linking into the kernel image depends on several linker symbols to be present it is recommended to use the linker script provided when bulding the kernel.

[![Travis-CI Status](https://api.travis-ci.org/RusPiRo/ruspiro-boot.svg?branch=master)](https://travis-ci.org/RusPiRo/ruspiro-boot)
[![Latest Version](https://img.shields.io/crates/v/ruspiro-boot.svg)](https://crates.io/crates/ruspiro-boot)
[![Documentation](https://docs.rs/ruspiro-boot/badge.svg)](https://docs.rs/ruspiro-boot)
[![License](https://img.shields.io/crates/l/ruspiro-boot.svg)](https://github.com/RusPiRo/ruspiro-boot#license)

## Hint

The usage of this crate does only make sense when building a Raspberry Pi 3 bare metal kernel. The crate has to be build with the feature ``ruspiro-pi3``. Without this, the crate might not compile properly or the binary build using this crate will not work as expected. Therfore this feature is activate by default.

## Usage
To use this crate simply add the following lines to your ``Cargo.toml`` file:
(hint: git dependency as long as the crate is not registered at crates.io)
```
[dependencies]
ruspiro-boot = { version = "0.1.0", features = ["with_panic", "with_exception"] }
```
The feature ``ruspiro_pi3`` is active by default and need not to be passed
The feature ``with_panic`` will ensure that a default panic handler is implemented.
The feature ``with_exception`` will ensure that a default exception and interrupt handler is implemented. However, if the interrupts are globaly active with eg. ``cpsie i`` than the default interrupt handler will simply deactiviate the global interrupts as it cannot acknowledge the incomming interrupt which could lead to endless interrupt loops.

To successfully link this crate it is **highly recomended** to use the linker script [link.ld](link.ld) for this step. This file defines all the necessary linker sections and symbols to allow this crate taking responsibility on the whole boot sequence of the Raspberry Pi in 32bit baremetal mode.

To refer to the linker script create a ``.cargo`` folder in your project root and add a file named ``config`` (without any file extension) to it. The file content shall be as follows:
```
[target.armv7-unknown-linux-gnueabihf]
linker = "arm-eabi-gcc"
rustflags = [
    "-C", "link-arg=-T<path_to_the_link_file>/link.ld",
    "-C", "target-cpu=cortex-a53",
    "-C", "target-feature=+a53,+fp-armv8,+v8,+vfp3,+d16,+thumb2,+neon",
    "-C", "opt-level=3",
    "-C", "debuginfo=0"
]
```
Just replace the ``<path_to_the_link_file>`` with the path where you stored the linker script file of this crate.


## License
Licensed under Apache License, Version 2.0, ([LICENSE](LICENSE) or http://www.apache.org/licenses/LICENSE-2.0)