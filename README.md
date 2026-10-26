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
| `openlane/double_wide_openframe_project_wrapper/` | The one LibreLane 3 config for the whole (flat) wrapper design. `cf harden` runs LibreLane 3 for `double_wide` projects automatically. |
| `openlane/double_wide_openframe_project_wrapper/pin_template.def` | Wrapper pin template from the harness. Do not edit. |
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

* `user_proj_counter` (`verilog/rtl/user_proj_counter.v`) is a plain RTL submodule; its reset is also driven by the frame `porb_l` and `resetb_l`, and reset release is synchronized to the clock.
* `double_wide_openframe_project_wrapper` instantiates it directly and configures every pad with [`CF_gpio_config`](verilog/rtl/CF_gpio_config.v) using the per-pad `gpio_loopback_one/zero` constants.
* There is only one `openlane/` design: the whole wrapper (GPIO config + your logic) is synthesized and hardened flat with LibreLane 3. LibreLane's own power-grid generator reaches the padframe-aligned `vccd1`/`vssd1` pins directly, so no separate macro or metal-only "connection" cell is needed to bridge power to the pads.

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

#### One flat design, hardened with LibreLane 3

Unlike `analog`/`digital`/`openframe` projects, `double_wide` has a single
`openlane/` design: the whole wrapper (your logic + GPIO pad configuration)
is synthesized and placed-and-routed together, the same way the upstream
Double-Wide OpenFrame template is built. `cf harden` detects the
`double_wide` project type and automatically runs **LibreLane 3** for it
(every other project type keeps using the standard LibreLane/OpenLane 2
version cf-cli normally pins) — LibreLane 3's power-grid generator reaches
the padframe-aligned `vccd1`/`vssd1` pins directly, so there is no separate
macro to harden and no metal-only "connection" cell bridging power to the
pads.

Add your logic as plain RTL submodules instantiated from
`verilog/rtl/double_wide_openframe_project_wrapper.v` (see
`user_proj_counter.v` for an example), list every new file in
`openlane/double_wide_openframe_project_wrapper/config.json` →
`VERILOG_FILES` and in `verilog/includes/includes.rtl.openframe_user_project`,
then harden the whole wrapper:

```bash
cf harden double_wide_openframe_project_wrapper
```

Views are written to `gds/`, `lef/`, `def/`, `mag/`, `lib/`, `spef/`,
`verilog/gl/` and `signoff/`.

The wrapper's constraints file
(`openlane/double_wide_openframe_project_wrapper/double_wide_openframe_project_wrapper.sdc`,
set as `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE`) models GPIO-driven inputs with
the characterized pad input transition and treats asynchronous reset inputs
as false paths. Adapt the clock, I/O delays and false paths to your design.
Protect your logic's inputs against wrapper-level antenna effects (the
example uses `DIODE_ON_PORTS: "in"`).

Magic/KLayout DRC and Netgen LVS are disabled during `cf harden` itself
(`meta.substituting_steps` in `config.json`) — full DRC/LVS signoff happens
with `cf precheck`, same as every other project type.

### Important Notes

**Power:**
* Connect digital logic to **`vccd1` / `vssd1`**. LibreLane's `GeneratePDN`
  step builds the grid and (via `PDN_ENABLE_PINS`, on by default) promotes
  the stripes that reach the core/die boundary into `vccd1`/`vssd1` block
  pins aligned with the padframe automatically.

**Wrapper contract:**
* The top module must be named `double_wide_openframe_project_wrapper`, with the port list of `caravel/verilog/rtl/__double_wide_openframe_project_wrapper.v`.
* The footprint (6754.63 × 4766.63 µm) and boundary pins are fixed by `pin_template.def`. `cf precheck` XORs the boundary against the harness golden wrapper.

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
- [ ] The wrapper keeps the fixed pin template (`pin_template.def`) and the padframe-matching `DIE_AREA`/`CORE_AREA`.
- [ ] Every GPIO is configured (including unused pads).
- [ ] `cf precheck` passes.
- [ ] This README describes your design.
