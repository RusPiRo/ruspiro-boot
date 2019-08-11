/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/

//! # Linker Stubs
//! 
//! The module provides stub implementations of functions needed by the linker even in baremetal environment. As
//! the final binary is not intended to run a real OS those functions typically have no content.

#[no_mangle]
fn __aeabi_unwind_cpp_pr0() {

}

#[no_mangle]
fn __aeabi_unwind_cpp_pr1() {
    
}

#[no_mangle]
#[allow(non_snake_case)]
fn _Unwind_Resume() {

}