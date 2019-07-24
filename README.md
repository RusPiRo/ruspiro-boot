# Boot crate for the RusPiRo kernel

This crate provides basic boot code that - when build into a kernel crate - will be executed as soon as the Raspberry Pi powers up. As the building of this crate and finally linking into the kernel image depends on several linker symbols to be present it is recommended to use the linker script provided when bulding the kernel.
