/***********************************************************************************************************************
 * Kick-off all other cores while booting the Raspberry Pi 
 *
 * Copyright (c) 2019 by the authors
 *
 * Author: André Borrmann
 * License: Apache License 2.0
 **********************************************************************************************************************/
 
.global __rust_entry

__rust_entry:
	// get current CPUid to pass it to the entry function
	mrs		x0, mpidr_el1
	and     x0, x0, #3
/*******************************************************
 * this is the entry point into the RUST environment
 *******************************************************/
	bl		__come_alive
	
/******************************************************
 * kickoff the next core
 ******************************************************/
// get current CPUid
	mrs		x0, mpidr_el1
	and     x0, x0, #3
	adr     x1, __boot
	
	cmp     x0, #0
	beq     .kick_core1

	cmp     x0, #1
	beq     .kick_core2

	b       .run_this_core

.kick_core1:
	mov     x2, #0xe0
	str     x1, [x0]
	sev
	b       .run_this_core

.kick_core2:
	mov     x2, #0xe8
	str     x1, [x0]
	sev
	b       .run_this_core

.run_this_core:
	sev
/*******************************************************
 * this is the second entry point into the RUST en-
 * vironment aiming for an endless running task on this core
 *******************************************************/
// get current CPUid
	mrs		x0, mpidr_el1
	and     x0, x0, #3

	b       __run	// this usually never returns!
	b       __hang	// but for safety hang the core here

