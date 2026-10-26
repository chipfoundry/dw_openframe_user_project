<div align="center">

<img src="https://umsousercontent.com/lib_lnlnuhLgkYnZdkSC/hj0vk05j0kemus1i.png" alt="ChipFoundry Logo" height="140" />

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Inter&size=44&duration=3000&pause=600&color=4C6EF5&center=true&vCenter=true&width=1100&lines=Double-Wide+OpenFrame+User+Project;LibreLane+%2B+ChipFoundry+Flow;Verification+and+Shuttle-Ready)](https://git.io/typing-svg)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ChipFoundry Marketplace](https://img.shields.io/badge/ChipFoundry-Marketplace-6E40C9.svg)](https://platform.chipfoundry.io/marketplace)

</div>

## Table of Contents
- [Overview](#overview)
- [Documentation & Resources](#documentation--resources)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Starting Your Project](#starting-your-project)
- [Development Flow](#development-flow)
- [Local Precheck](#local-precheck)
- [Checklist for Shuttle Submission](#checklist-for-shuttle-submission)

## Overview
Double-Wide OpenFrame is a ChipFoundry project template that provides only a bare padframe (no integrated SoC), giving you a **32 mm² user area** (6754.63 × 4766.63 µm) and **63 GPIOs** to design your own custom chip. It is twice as wide as the standard OpenFrame and keeps the same pad interface, including the frame power-on reset (`porb_h`, `porb_l`, `por_l`), the master reset (`resetb_h`, `resetb_l`) and per-pad constant one/zero loopbacks.

You implement your design and connect it directly to the GPIOs through the pins of `double_wide_openframe_project_wrapper`. The whole flow (setup, hardening, simulation, precheck, submission) is driven by the ChipFoundry CLI (`cf`); no Makefiles are needed.

---

## Documentation & Resources
* **[Double-Wide OpenFrame harness](https://github.com/chipfoundry/double_wide_openframe)**: padframe, empty wrapper template, datasheet and pinout. `cf setup` installs it into `caravel/`.
* **[Datasheet](https://github.com/chipfoundry/double_wide_openframe/blob/main/docs/datasheet.md)**: die/user-area geometry, I/O map, power domains, GPIO and reset interface.
* **[Pinout](https://github.com/chipfoundry/double_wide_openframe/blob/main/docs/pinout.md)**: GPIO index map and bond-pad coordinates.
* **[ChipFoundry Marketplace](https://platform.chipfoundry.io/marketplace)**: additional IP blocks, EDA tools, and shuttle services.

---

## Prerequisites
1. **Docker** [Linux](https://docs.docker.com/desktop/setup/install/linux/ubuntu/) | [Windows](https://docs.docker.com/desktop/setup/install/windows-install/) | [Mac](https://docs.docker.com/desktop/setup/install/mac-install/) (precheck and cocotb simulation).
2. **Nix** (recommended) or Docker for LibreLane hardening.
3. **Python 3.8+** with `pip` and `venv`.
4. **Git**.

---

## Project Structure

| Path | Description |
| :--- | :--- |
| `openlane/` | LibreLane configurations: one directory per macro, plus `double_wide_openframe_project_wrapper/`. |
| `openlane/double_wide_openframe_project_wrapper/fixed_dont_change/` | Wrapper pin template from the harness. Do not edit. |
| `verilog/rtl/` | RTL sources. |
| `verilog/gl/` | Gate-level netlists written by `cf harden`. |
| `verilog/dv/cocotb/` | cocotb tests run by `cf verify`. |
| `verilog/includes/` | File lists used by `cf verify` (`includes.{rtl,gl}.openframe_user_project`). |
| `gds/`, `lef/`, `def/`, `mag/`, `lib/`, `spef/`, `signoff/` | Hardened views written by `cf harden`. |
| `lvs/double_wide_openframe_project_wrapper/` | LVS configuration used by `cf precheck`. |
| `.cf/` | ChipFoundry metadata. `project.json` is created by `cf init` and is not committed. |

### Example design
The template ships a small, fully hardened example so every flow step works out of the box:

| GPIO | Use |
| :--- | :--- |
| 0 | user clock (input) |
| 1 | active-low reset (input with pull-up) |
| 13:2 | `count[11:0]` (outputs) |
| 62:14 | unused, configured as analog (high impedance) |

* `user_proj_counter` (`verilog/rtl/user_proj_counter.v`) is a hardened macro; its reset is also driven by the frame `porb_l` and `resetb_l`, and reset release is synchronized to the clock.
* `double_wide_openframe_project_wrapper` instantiates the macro and configures every pad with [`CF_gpio_config`](verilog/rtl/CF_gpio_config.v) using the per-pad `gpio_loopback_one/zero` constants.
* `dw_vccd1_connection` / `dw_vssd1_connection` are metal-only macros joining the east-edge `vccd1`/`vssd1` pins to the wrapper core ring. Keep them in your wrapper.

---

## Starting Your Project

### 1. Repository Setup
Create a repository from the `dw_openframe_user_project` template and clone it:

```bash
git clone <your-github-repo-URL>
cd <project_name>
pip install chipfoundry-cli
```

### 2. Project Initialization

> [!IMPORTANT]
> Run this first:

```bash
cf init
```

Choose project type **`double_wide`**. This creates `.cf/project.json`; every other command depends on it.

### 3. Environment Setup

```bash
cf setup
```

This installs, inside the project:

* `caravel/`: the Double-Wide OpenFrame harness (padframe, golden empty wrapper, simulation top-level).
* `openlane/.venv`: LibreLane (the hardening flow itself runs through Nix or Docker).
* `dependencies/pdks`: the sky130 PDK (via Ciel).
* `dependencies/timing-scripts`: static timing analysis scripts.
* `venv-cocotb`: caravel-cocotb, plus the `chipfoundry/dv:cocotb` Docker image.
* `cf-precheck`.

---

## Development Flow

### Hardening the Design

#### Macro hardening
Each macro has a directory under `openlane/` with its `config.json`:

```bash
cf harden --list
cf harden user_proj_counter
```

Views are written to `gds/`, `lef/`, `def/`, `mag/`, `lib/`, `spef/`, `verilog/gl/` and `signoff/`.

Each design has its own constraints file (`openlane/<design>/<design>.sdc`, set as `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE`). Inputs fed by GPIO pads are modelled with the characterized pad input transition, and asynchronous reset inputs are false paths. Adapt the clock, I/O delays and false paths to your design.

#### Integration
Instantiate your macros in `verilog/rtl/double_wide_openframe_project_wrapper.v`, then update `openlane/double_wide_openframe_project_wrapper/`:

* `config.json` → `MACROS`: one entry per macro with its `gds`, `lef`, `nl`, per-corner `lib`/`spef` views and the placement of each instance. Keep the two connection macros at their given locations.
* `config.json` → `FP_PDN_MACRO_HOOKS`: connect each macro instance to `vccd1`/`vssd1`.
* `double_wide_openframe_project_wrapper.sdc`: clocks and constraints seen at the wrapper boundary.

Also add your macros to `verilog/includes/` and to `LVS_VERILOG_FILES` in `lvs/double_wide_openframe_project_wrapper/lvs_config.json`.

#### Wrapper hardening

```bash
cf harden double_wide_openframe_project_wrapper
```

The wrapper is elaboration-only (no standard cells at the top level): it routes macro pins to the fixed boundary pins and builds the `vccd1`/`vssd1` core ring and straps. Because nothing is buffered at the top level, place macros so their pins sit close to the pads they connect to, and protect macro inputs against wrapper-level antenna effects (the example uses `DIODE_ON_PORTS: "in"`).

### Important Notes

**Power:**
* Connect digital logic to **`vccd1` / `vssd1`**; macros are hooked to the wrapper grid through `FP_PDN_MACRO_HOOKS`.
* The east-edge `vccd1`/`vssd1` pins reach the ring through `dw_vccd1_connection` / `dw_vssd1_connection`.

**Wrapper contract:**
* The top module must be named `double_wide_openframe_project_wrapper`, with the port list of `caravel/verilog/rtl/__double_wide_openframe_project_wrapper.v`.
* The footprint (6754.63 × 4766.63 µm) and boundary pins are fixed by `fixed_dont_change/double_wide_openframe_project_wrapper.def`. `cf precheck` XORs the boundary against the harness golden wrapper.

**GPIO configuration:**
* Every pad's `dm`, `inp_dis`, `oeb` and analog controls must be driven. Use `CF_gpio_config` (or loopback constants) for every GPIO, including unused ones. `cf gpio-config` does not apply to double-wide projects.

### Verification

cocotb tests live in `verilog/dv/cocotb/<test>/` and are registered in `cocotb_tests.py`. `cf verify` runs them at chip level: the testbench drives the padframe pins of the harness (`caravel/verilog/rtl/toplevel_cocotb.v`), so the full path from pad to your logic is simulated.

```bash
cf verify counter              # RTL
cf verify counter --sim gl     # gate level (after hardening)
cf verify --all                # every test in user_proj_tests/user_proj_tests.yaml
cf verify --all --sim gl       # every test in user_proj_tests/user_proj_tests_gl.yaml
```

The cocotb environment (`OpenFrame_env`) exposes `drive_gpio`, `release_gpio`, `monitor_gpio(_range)` for GPIOs 0-62, and `dut.resetb_tb` for the master reset pad.

---

## Local Precheck

```bash
cf precheck
```

For double-wide projects `cf precheck` uses the harness installed in `caravel/` as the golden reference (XOR boundary, port list). Useful options:

```bash
cf precheck --checks xor lvs     # run specific checks
cf precheck --skip-checks lvs    # skip checks
cf precheck --magic-drc          # include the optional Magic DRC
```

---

## Checklist for Shuttle Submission
- [ ] Top-level macro is named `double_wide_openframe_project_wrapper`.
- [ ] `cf verify --all` and `cf verify --all --sim gl` pass.
- [ ] All macros and the wrapper are hardened with `cf harden` and their views are committed.
- [ ] The wrapper keeps the fixed pin template and the `vccd1`/`vssd1` connection macros.
- [ ] Every GPIO is configured (including unused pads).
- [ ] `cf precheck` passes.
- [ ] This README describes your design.
