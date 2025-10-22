#  AHB-to-APB Bridge (SystemVerilog)

##  Overview
This project implements an **AMBA AHB-to-APB Bridge** in **Verilog**, which acts as an interface between the **high-performance AHB bus** and the **low-power APB bus**.  
The bridge converts AHB transactions into corresponding APB transfers, handling synchronization, protocol conversion, and control signal generation.

---

##  Architecture

###  AMBA Bus Differences

| Feature | AHB (Advanced High-performance Bus) | APB (Advanced Peripheral Bus) |
|----------|-------------------------------------|--------------------------------|
| Speed | High-speed | Low-speed |
| Nature | Pipelined, burst transfers | Simple, non-pipelined |
| Masters | Multiple | Single (bridge is master) |
| Signals | `HADDR`, `HWRITE`, `HWDATA`, `HRDATA`, `HTRANS`, etc. | `PADDR`, `PWRITE`, `PWDATA`, `PRDATA`, `PSEL`, `PENABLE`, etc. |

The **bridge** acts as the **slave** on the AHB side and as the **master** on the APB side.

---

##  Working Principle

The bridge is controlled by a **finite state machine (FSM)** that converts AHB protocol signals into APB-compatible transactions.
###  State Machine Overview

| **State** | **Description** |
|------------|-----------------|
| **IDLE** | Waits for a valid AHB transfer (`HSEL=1` and `HTRANS` valid). |
| **SETUP** | Captures AHB address, data, and control; drives APB setup signals (`PSEL=1`, `PENABLE=0`). |
| **ACCESS** | Starts the APB enable phase (`PENABLE=1`). Actual transfer occurs. |
| **WAIT_PREADY** | Waits for `PREADY` from the APB slave (for slower peripherals). |
| **COMPLETE** | Finishes transfer, deasserts signals, and returns `HREADY=1` to AHB. |

---

###  Step-by-Step Working

####  AHB to APB Write Transfer
1. AHB master issues a write request (`HWRITE=1`).
2. Bridge captures `HADDR` and `HWDATA`.
3. In APB **SETUP** phase, it drives:
PSEL = 1
PADDR = HADDR
PWRITE = 1
PWDATA = HWDATA
PENABLE = 0

4. In **ACCESS** phase, bridge asserts `PENABLE=1`.
5. When `PREADY=1`, data is written to the APB slave.
6. Bridge deasserts `PSEL` and `PENABLE`, then sets `HREADY=1`.

#### AHB to APB Read Transfer
1. AHB master issues a read request (`HWRITE=0`).
2. Bridge captures `HADDR`.
3. In APB **SETUP** phase:

PSEL = 1
PADDR = HADDR
PWRITE = 0
PENABLE = 0

4. In **ACCESS** phase, `PENABLE=1`.
5. When `PREADY=1`, bridge captures `PRDATA` and sends it back as `HRDATA`.
6. Transaction completes with `HREADY=1`.

---

##  Signal Behavior Summary

| **State** | **PSEL** | **PENABLE** | **HREADY** | **Description** |
|------------|-----------|-------------|-------------|-----------------|
| IDLE | 0 | 0 | 1 | Waiting for AHB request |
| SETUP | 1 | 0 | 0 | Drive APB setup signals |
| ACCESS | 1 | 1 | 0 | APB transfer in progress |
| WAIT_PREADY | 1 | 1 | 0→1 | Wait for APB slave ready |
| COMPLETE | 0 | 0 | 1 | Transfer done, return to idle |

---

##  Features

- Supports both **read** and **write** transfers  
- Handles **wait states** using `PREADY`  
- Supports **error signaling** using `PSLVERR → HRESP`  
- Implements **two-phase APB protocol** (SETUP + ENABLE)  
- Fully **synthesizable** and **simulation-ready** in SystemVerilog

---

##  Files in Repository

| File | Description |
|------|--------------|
| `design.v` | Core bridge RTL implementation |
| `testbench.v` | Testbench for functional verification |
| `waveform.do` | Optional ModelSim/EDA Playground waveform setup |

---


###  Using EDA Playground / ModelSim
1. Upload all `.v` files to your workspace.
2. Run with:
```bash
vlog *.v
vsim -c -do "run -all"


