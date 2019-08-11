/*********************************************************************************************************************** 
 * Copyright (c) 2019 by the authors
 * 
 * Author: André Borrmann 
 * License: Apache License 2.0
 **********************************************************************************************************************/

//! # Macros
//! 
//! This module provides macros to ease the assignment of custom functions for the entypoints into the code provided by
//! the consumer of this crate

/// Use this macro to define the your custom one-time-initialization entry point function to be used once the mandatory
/// boot process has finished and the processing is handed over to the high level rust code. As each core will come
/// come alive **one after another**, this function is called with the core it's running on. The next core comes alive
/// after the actual one finished processing this function
/// 
/// # Example
/// ```
/// come_alive_with!(my_init_once);
/// 
/// fn my_init_once(core: u32) {
///     // do any one-time initialization here....
/// }
/// ```
/// 
#[macro_export]
macro_rules! come_alive_with {
    // macro used with a path given to it matches this branch
    ($path:path) => {
        // in this case the macro expends to an library export symbol called __come_alive
        // this function is called from the boot up sequence
        #[export_name = "__come_alive"]
        pub unsafe fn __entry(core: u32)  {
            let entry_f: fn(u32) = $path;
            entry_f(core);            
        }
    };
}

/// Use this macro to define the never-returning processing entry point function to be used for the processing
/// after all one-time initializations have been done. This function is intended to never return and is executed
/// on each core individually. Therefore this function is called with the core number it's running on.
/// 
/// # Example
/// ```
/// run_with!(my_processing);
/// 
/// fn my_processing(core: u32) -> ! {
///     loop { } // safely hang here as we should never return.
/// }
/// ```
/// 
#[macro_export]
macro_rules! run_with {
    // macro used with a path given to it matches this branch
    ($path:path) => {
        // in this case the macro expends to an library export symbol called __run
        // this function is called from the boot up sequence
        #[export_name = "__run"]
        pub unsafe fn __run_loop(core: u32)  {
            let run_f: fn(u32) -> ! = $path;
            run_f(core);            
        }
    };
}
