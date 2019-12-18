#*****************************************************************
# Makefile to build the RusPiRo test kernel that verifies
# it could be loaded using the bootloader
#
# Copyright (c) 2019 by the authors
# 
# Author: André Borrmann 
# License: Apache License 2.0
#******************************************************************


all32: export CFLAGS = -mfpu=neon-fp-armv8 -mfloat-abi=hard -march=armv8-a -Wall -O3 -nostdlib -nostartfiles -ffreestanding -mtune=cortex-a53
all32: export RUSTFLAGS = -C linker=arm-eabi-gcc.exe -C target-cpu=cortex-a53 -C target-feature=+strict-align,+a53,+fp-armv8,+v8,+vfp3,+d16,+thumb2,+neon -C link-arg=-nostartfiles -C link-arg=-T./link32.ld -C opt-level=3 -C debuginfo=0
all32: export CC = arm-eabi-gcc.exe
all32: export AR = arm-eabi-ar.exe
all32: 
	cargo xbuild --target armv7-unknown-linux-gnueabihf --release --lib --target-dir ./target/


all64: export CFLAGS = -march=armv8-a -Wall -O3 -nostdlib -nostartfiles -ffreestanding -mtune=cortex-a53
all64: export RUSTFLAGS = -C linker=aarch64-elf-gcc.exe -C target-cpu=cortex-a53 -C target-feature=+strict-align,+a53,+fp-armv8,+neon -C link-arg=-nostartfiles -C opt-level=3 -C debuginfo=0 -C link-arg=-T./link64.ld
all64: export CC = aarch64-elf-gcc.exe
all64: export AR = aarch64-elf-ar.exe
all64: 
	cargo xbuild --target aarch64-unknown-linux-gnu --release --lib --target-dir ./target/


doc: export CFLAGS = -march=armv8-a -Wall -O3 -nostdlib -nostartfiles -ffreestanding -mtune=cortex-a53
doc: export RUSTFLAGS = -C linker=aarch64-elf-gcc.exe -C target-cpu=cortex-a53 -C target-feature=+strict-align,+a53,+fp-armv8,+neon -C link-arg=-nostartfiles -C opt-level=3 -C debuginfo=0
doc: export CC = aarch64-elf-gcc.exe
doc: export AR = aarch64-elf-ar.exe
doc: 
	cargo doc --no-deps --target aarch64-unknown-linux-gnu --release --open

clean:
	cargo clean