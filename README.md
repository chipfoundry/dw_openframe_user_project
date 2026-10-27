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
| `openlane/double_wide_openframe_project_wrapper/` | LibreLane 3 config for the top-level wrapper (elaborate-only shell + GPIO config + `MACROS` placement of your macros). `cf harden` runs LibreLane 3 for `double_wide` projects automatically. |
| `openlane/double_wide_openframe_project_wrapper/pin_template.def` | Wrapper pin template from the harness. Do not edit. |
| `openlane/user_proj_counter/` | LibreLane 3 config for the example `user_proj_counter` macro, hardened on its own and placed into the wrapper. Add one `openlane/<macro>/` directory per macro your design needs. |
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

* `user_proj_counter` (`verilog/rtl/user_proj_counter.v`) is hardened on its own as a macro (`openlane/user_proj_counter/`); its reset is also driven by the frame `porb_l` and `resetb_l`, and reset release is synchronized to the clock.
* `double_wide_openframe_project_wrapper` places it via a `MACROS` entry in its own `config.json` and configures every pad with [`CF_gpio_config`](verilog/rtl/CF_gpio_config.v) using the per-pad `gpio_loopback_one/zero` constants. This is the same macro+wrapper split `openframe_project_wrapper` uses for `user_proj_timer` and `user_project_wrapper` uses for `user_proj_example`: the wrapper has no standard cells of its own, so it is hardened `SYNTH_ELABORATE_ONLY` and carries only the GPIO-config wiring and the macro instance.
* LibreLane's own power-grid generator reaches the padframe-aligned `vccd1`/`vssd1` pins directly (`PDN_ENABLE_PINS`), and `PDN_MACRO_CONNECTIONS` stitches each macro's power pins into that same grid, so no metal-only "connection" cell is needed to bridge power to the pads.

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

#### Macro + wrapper split, hardened with LibreLane 3

`double_wide` follows the same macro+wrapper split as `openframe_project_wrapper`
(`user_proj_timer`) and `user_project_wrapper` (`user_proj_example`): each
piece of real logic is hardened on its own as a dense macro in its own
`openlane/<macro>/` directory, then placed into the top-level wrapper through
a `MACROS` entry. The wrapper itself has no standard cells of its own — it is
`SYNTH_ELABORATE_ONLY`, carrying only the GPIO pad configuration
(`CF_gpio_config`) and the macro instance(s). `cf harden` detects the
`double_wide` project type and automatically runs **LibreLane 3** for it
(every other project type keeps using the standard LibreLane/OpenLane 2
version cf-cli normally pins) — LibreLane 3's power-grid generator reaches
the padframe-aligned `vccd1`/`vssd1` pins directly (`PDN_ENABLE_PINS`), and
`PDN_MACRO_CONNECTIONS` stitches each macro's power pins into that same grid,
so no metal-only "connection" cell is needed to bridge power to the pads.

To add your own logic: create a new `openlane/<macro>/config.json` for it
(see `openlane/user_proj_counter/config.json` for a template), harden the
macro on its own, then add a `MACROS` entry for it in
`openlane/double_wide_openframe_project_wrapper/config.json` pointing at the
macro's `gds`/`lef`/`nl`/`spef`/`lib` views and an `instances` placement, and
instantiate it (or a blackbox stub read via `EXTRA_VERILOG_MODELS`) from
`verilog/rtl/double_wide_openframe_project_wrapper.v`. List every macro's
hardened netlist in both `openlane/user_proj_counter/config.json` →
`VERILOG_FILES` and `verilog/includes/includes.rtl.openframe_user_project`,
then harden each macro and the wrapper:

```bash
cf harden user_proj_counter
cf harden double_wide_openframe_project_wrapper
```

Views are written to `gds/`, `lef/`, `def/`, `mag/`, `lib/`, `spef/`,
`verilog/gl/` and `signoff/` for both the macro(s) and the wrapper.

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
