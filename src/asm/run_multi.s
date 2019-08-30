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
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3
/*******************************************************
 * this is the entry point into the RUST environment
 *******************************************************/
	bl		__come_alive
	
/******************************************************
 * kickoff the next core
 ******************************************************/
// get current CPUid
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #0x3
	cmp		r0, #0x3
	bge     .no_further_core // no further core need to be kicked off

	ldr		r1, =__boot		// each core start at the same entry point
	ldr		r2, =0x4000008C // inter core mailbox base address for core 0
	mov     r4, #0x10		// core mailbox offset between cores
	add     r3, r0, #0x1		// add 1 to the current core id to kick off the next one
	mul		r3, r3, r4   	// core mailbox offset for the next core
	str 	r1, [r2, r3]		// set start address of the next core
	sev						// kick off next core as it was suspended with wfe

.no_further_core:
/*******************************************************
 * this is the second entry point into the RUST en-
 * vironment aiming for an endless running task on this core
 *******************************************************/
	// get current CPUid to pass it to the entry function
	mrc		p15, 0, r0, c0, c0, 5		/* read MPIDR */
	and     r0, r0, #3
	b       __run				// this usually never returns! r0 = current core id passed along
	b       __hang

