/***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann <pspwizard@gmx.de>
 * License: Apache License 2.0 / MIT
 **********************************************************************************************************************/

//! # Macros
//!
//! This module provides macros to ease the assignment of custom functions for the entypoints into the code provided by
//! the consumer of this crate

/// Use this macro to define the your custom one-time-initialization entry point function to be used once the mandatory
/// boot process has finished and the processing is handed over to the high level rust code. As each core will come
/// alive **one after another**, this function is called with the core id/number it's running on. The next core comes
/// alive after the actual one finished processing this function, it is guaranteed that the cores will come alive in
/// sequence!
///
/// # Example
/// ```ignore
/// # use ruspiro_boot::come_alive_with;
/// come_alive_with!(my_init_once);
///
/// fn my_init_once(core: u32) {
///     // do any one-time initialization here....
/// }
/// ```
#[macro_export]
macro_rules! come_alive_with {
  ($path:path) => {
    // in this case the macro expends to an library export symbol called __kernel_startup
    // this function is called from the boot up sequence
    #[export_name = "__kernel_startup"]
    pub fn __entry(core: u32) {
      let entry_f: fn(u32) = $path;
      entry_f(core);
    }
  };
}

/// Use this macro to define the never-returning processing entry point function to be used for the processing
/// after all one-time initializations have been done. This function is intended to never return and is executed
/// on each core individually. Therefore this function is called with the core id/number it's running on.
///
/// # Example
/// ```ignore
/// # use ruspiro_boot::run_with;
/// run_with!(my_processing);
///
/// fn my_processing(core: u32) -> ! {
///     loop { } // safely hang here as we should never return.
/// }
/// ```
#[macro_export]
macro_rules! run_with {
  // macro used with a path given to it matches this branch
  ($path:path) => {
    // in this case the macro expends to an library export symbol called __kernel_run
    // this function is called from the boot up sequence
    #[export_name = "__kernel_run"]
    pub fn __run_loop(core: u32) {
      let run_f: fn(u32) -> ! = $path;
      run_f(core);
    }
  };
}
