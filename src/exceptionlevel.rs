/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: ???
 **********************************************************************************************************************/

//! # Exception Level handling
//! 

use ruspiro_register::system::*;

pub fn switch_to_el1() {
    // get the current EL
    let current = currentel::read(currentel::el::Field);
    if current.value() == 2 {
        // we are currently at EL2 -> switch to EL1
        // rely on assembly core provided by the boot strapper for the time beeing
        extern "C" { fn __switch_el2_to_el1(); }
        unsafe { __switch_el2_to_el1(); }
        // from this time onwards we are at EL1
        // do some additional config for EL1
        // prevent trapping of FP/NEON instracutions
        cpacr_el1::write(cpacr_el1::fpen::NO_TRAP);
    }
}