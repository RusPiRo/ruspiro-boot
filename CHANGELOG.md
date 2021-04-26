# Changelog

## :cat: v0.5.2

Introduce the custom build target `aarch64-ruspiro` to the crate. This version also introduces an example folder (this is nmot published to crates.io) that contains a minimalistic Raspberry Pi 3 baremetal kernel using this boot crate.

## :cat: v0.5.1

Migrate the actual travis-ci build pipeline to github actions

## :cat: v0.5.0

Incorporate the basic exception handling within the boot loading crate instead of delegating the whole stuff to the `ruspiro-interrupt` crate. Now only the interrupt and fast-interrupt related exeptions will be delegated to an external crate that implements and exports this function: `extern "C" fn __isr_default() {}`.

- ### :bulb: Features

  - Bake the basic exception handling into this crate (e.g. aborts, SVCor HVC calls, instruction exceptions etc)
  - Delegate IRQ and FIQ to an external crate
  - Use the `log` crate to use it's logging macros to create log entries in case of exception events.

## :strawberry: v0.4.2

Adjust the linker script to discard specific sections. With the sections in place build on travis for the custom unit test framework lead to a wrong start memory address for the kernel used with *QEMU*.

- ### :detective: Fixes

  - Discard `*.note.gnu*` section in the linker script.

## :strawberry: v0.4.1

  Fxing the linker script. Some of the section requires re-ordering to properly link with new versions of LLVM/LLD used in the current rustc version.

- ### :detective: Fixes

  - re-order sections in the linker script file

## :peach: v0.4.0

  Refactoring the crate into a more lightweight 64Bit only version. This now provides a tailormade lean implementation to boot up the Raspberry Pi either in *multicore* or *singlecore* setup. The boot sequence hands processing to an entry functions that needs to be implemented by the user of this crate. The implementer of this entry point function does have now full freedom where to go from here. As part of the boot sequence there is nomore a forced setup of the MMU or any other peripheral.

- ### :wrench: Maintenance

  - use a proper travis-ci pipeline setup
  - remove aarch32 support during boot up
  - instead of the feature `singlecore` to prevent multicore boot up, the default is now single-core and the feature `multicore` enables multi-core boot up
  - a conditional compilation flag ensures this crate does only build with useful content if the target architecture is *Aarch64*

## :banana: v0.3.2

- ### :wrench: Maintenance

  - use `cargo make` to stabilize build
  - change usage of `asm!` macro into `llvm_asm!`

## :apple: v0.3.1

- ### :bulb: Features

  - add some console log statements in the panic handler that gives a clue of the panic when at least the console could be setup properly before panicing the first time :)
  - use Raspberry Pi Mailbox to retrieve clock speed to initialize miniUart with

- ### :detective: Fixes

  - Fix the path created by the build script pointing to the linker script file. It should not contain a '\\\\'. In addition the examples for the build script to be implementend on consumer side was updated.
  - Fix issues with the exception calls and returns as several registers where trashed that should have been preserved

- ### :wrench: Maintenance

  - Use additional ``cfg`` and ``cfg_attr`` to enable running ``cargo test`` which requires some functions from ``std``.
  - Update to latest ``ruspiro-register`` version
  - Remove ``ruspiro-gpio`` dependency
  - Remove the ``ruspiro_interrupt`` dependencie to let the using crate decide whether to incorporate interrupt handling or not. This than also includes the crate introducing interrupt handling usage need to proper initialize interrupt handling.

## :carrot: v0.3.0

- ### :bulb: Features
  Refactor the boot strapping code to support `Aarch32` and `Aarch64` build target architectures.

  The boot strapping code is run at the very first moment the Raspberry Pi boots up and the GPU hands over execution to the CPU. The boot strapper could be built to run in `singlecore` mode.

  The boot strapping switches all cores into exception level EL1(aarch64)/SVC(aarch32) and initializes the MMU with a default 1:1 mapping accross the whole available memory.

  The boot strapping also sets up exception handling and provides a generic default exception handler that is ready to be implemented by the user of this crate.

  The miniUart of the Raspberry Pi is initialized and attached to the global CONSOLE which enables users of this crate to use the macros `print!`and `println!` to conviniently write to the uart console. The feature set of both macros is equivalent to the `rust_std` versions.
