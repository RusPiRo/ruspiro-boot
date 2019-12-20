# Changelog
## :apple: v0.3.1
  - ### :detective: Fixes
    Fix the path created by the build script pointing to the linker script file. It should not contain a '\\\\'. In addition the examples for the build script to be implementend on consumer side was updated.
    
## :carrot: v0.3.0
  - ### :bulb: Features
    Refactor the boot strapping code to support `Aarch32` and `Aarch64` build target architectures.
    
    The boot strapping code is run at the very first moment the Raspberry Pi boots up and the GPU
    hands over execution to the CPU. The boot strapper could be built to run in `singlecore` mode.
    
    The boot strapping switches all cores into exception level EL1(aarch64)/SVC(aarch32) and
    initializes the MMU with a default 1:1 mapping accross the whole available memory.

    The boot strapping also sets up exception handling and provides a generic default exception
    handler that is ready to be implemented by the user of this crate.

    The miniUart of the Raspberry Pi is initialized and attached to the global CONSOLE which enables
    users of this crate to use the macros `print!`and `println!` to conviniently write to the uart console. The feature
    set of both macros is equivalent to the `rust_std` versions.
