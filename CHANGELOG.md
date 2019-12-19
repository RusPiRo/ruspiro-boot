# Changelog
## :carrot: v0.3.0
  - ### :bulb: Features
    Refactor the boot strapping code to support `Aarch32` and `Aarch64` build target architectures.
    
    The boot strapping code is run at the very first moment the Raspberry Pi boots up and the GPU hands over execution to the CPU. The boot strapper could be built to run in `singlecore` mode.
    
    The boot strapping switches all cores into exception level EL1(aarch64) or SVC(aarch32) and initializes the MMU with a default 1:1 mapping accross the whole available memory.

    The boot strapping also sets up exception handling and provides a generic default exception handler that is ready to be implemented by the user of this crate

