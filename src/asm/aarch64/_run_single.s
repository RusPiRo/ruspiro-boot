/***********************************************************************************************************************
 * Do not kick-off further cores when booting the Raspberry Pi
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
.global __rust_entry

__rust_entry:
    // get the current CPIid to pass it to the entry function
    mrs     x0, mpidr_el1
    and     x0, x0, #3
/*******************************************************
 * this is the entry point into the RUST environment
 *******************************************************/
    bl      __come_alive

/*******************************************************
 * this is the second entry point into the RUST en-
 * vironment aiming for an endless running task on this core
 *******************************************************/
	// get current CPUid to pass it to the entry function
    mrs     x0, mpidr_el1
    and     x0, x0, #3

    b       __run   // this usually never returns!
    b       __hang  // but for safety hang the core here
