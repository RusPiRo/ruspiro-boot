/***********************************************************************************************************************
 * Copyright (c) 2020 by the authors
 *
 * Author: André Borrmann <pspwizard@gmx.de>
 * License: Apache License 2.0 / MIT
 **********************************************************************************************************************/

//! # Core exception handling
//!
//! Default implementation to handle exeptions that can be raised by the cores
//!

use log::*;

/// The different exceptions that are handled by the exception vector configured during
/// the initialization phase of each core
#[allow(dead_code)]
#[repr(u32)]
pub enum ExceptionType {
  CurrentElSp0Sync = 0x01,
  CurrentElSp0Irq = 0x02,
  CurrentElSp0Fiq = 0x03,
  CurrentElSp0SErr = 0x04,

  CurrentElSpxSync = 0x11,
  CurrentElSpxIrq = 0x12,
  CurrentElSpxFiq = 0x13,
  CurrentElSpxSErr = 0x14,

  LowerEl64SpxSync = 0x21,
  LowerEl64SpxIrq = 0x22,
  LowerEl64SpxFiq = 0x23,
  LowerEl64SpxSErr = 0x24,

  LowerEl32SpxSync = 0x31,
  LowerEl32SpxIrq = 0x32,
  LowerEl32SpxFiq = 0x33,
  LowerEl32SpxSErr = 0x34,

  A32UndefInstruction = 0x50,
  A32SoftwareInterrupt = 0x51,
  A32PrefetchAbort = 0x52,
  A32DataAbort = 0x53,
  A32Irq = 0x54,
  A32Fiq = 0x55,
}

/// The default exception handler.
/// This is the entry point for any exception taken at any core. The type gives the hint on what
/// the exyception is about, sync, irq, etc. This entry point is called from the ``ruspiro-boot``
/// crate when this is used for bootstrapping. Otherwise the custom bootstrapping need to properly
/// setup the exception table and call this entry point with the required input
///
//#[cfg(target_arch = "aarch64")]
#[no_mangle]
pub unsafe extern "C" fn __exception_handler_default(
  exception: ExceptionType,
  esr: u64,
  spsr: u64,
  far: u64,
  elr: u64,
) {
  match exception {
    ExceptionType::CurrentElSpxSync => {
      error!(
        "Exeption - pc: {:#x}, addr: {:#x}, spsr: {:#x}",
        elr, far, spsr
      );
      let esr_ec = esr >> 26;
      warn!("esr_ec: {:#b}", esr_ec);
      let esr_iss = esr & 0x01FF_FFFF;
      match esr_ec {
        0b000000 => {
          panic!("Unknown Reason");
        }
        0b010001 => {
          panic!("SVC in a32 instruction called");
        }
        0b010010 => {
          panic!("HVC in a32 instruction called");
        }
        0b010011 => {
          panic!("SMC in a32 instruction called");
        }
        0b010101 => {
          panic!("SVC in a64 instruction called");
        }
        0b010110 => {
          panic!("HVC in a64 instruction called");
        }
        0b010111 => {
          panic!("SMC in a64 instruction called");
        }
        0b100001 => {
          panic!("instruction abort");
        }
        0b100100 => {
          panic!("data abort lower EL");
        }
        0b100101 => {
          error!("Data Abort Exeption - {:#b}", esr_iss);
          if (esr_iss & (1 << 8)) == 1 << 8 {
            debug!("Cache Maintenance")
          };
          if (esr_iss & (1 << 6)) == 1 << 6 {
            debug!("Write")
          } else {
            debug!("Read")
          };
          if (esr_iss & 0x3F) == 0b000100 {
            debug!("Translation Level 0")
          };
          if (esr_iss & 0x3F) == 0b000101 {
            debug!("Translation Level 1")
          };
          if (esr_iss & 0x3F) == 0b000110 {
            debug!("Translation Level 2")
          };
          if (esr_iss & 0x3F) == 0b000111 {
            debug!("Translation Level 3")
          };
          if (esr_iss & 0x3F) == 0b100001 {
            debug!("Alignment Fault - FAR {:#x} - ELR {:#x}", far, elr)
          };
          panic!("data abort same EL");
        }
        0b111100 => {
          // this is a BRK instruction used for endless loops, so just silently ignore
          // and halt here
          info!("BRK instruction");
          loop {}
        }
        _ => panic!("unhandled sync exception"),
      }
    }
    ExceptionType::CurrentElSp0Irq => __isr_default(),
    ExceptionType::CurrentElSp0Fiq => __isr_default(),
    ExceptionType::CurrentElSpxIrq => __isr_default(),
    ExceptionType::CurrentElSpxFiq => __isr_default(),
    _ => error!("unhandled exeption"),
  }
}

/// Provide a waek linked default interrupt service routine.
/// As soon as any other crate (e.g. `ruspiro-interrupt`) is linked with this one
/// the linkage will be overruled with the proper implementation.
#[linkage = "weak"]
#[no_mangle]
extern "C" fn __isr_default() {}
