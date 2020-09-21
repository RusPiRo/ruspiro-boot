/***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann <pspwizard@gmx.de>
 * License: Apache License 2.0 / MIT
 **********************************************************************************************************************/

//! # Linker Stubs
//!
//! The module provides stub implementations of functions needed by the linker even in baremetal environment. As
//! the final binary is not intended to run a real OS those functions typically have no content.

#[no_mangle]
#[linkage = "weak"]
fn __aeabi_unwind_cpp_pr0() {}

#[no_mangle]
#[linkage = "weak"]
fn __aeabi_unwind_cpp_pr1() {}

#[no_mangle]
#[linkage = "weak"]
#[allow(non_snake_case)]
extern "C" fn _Unwind_Resume() {}
