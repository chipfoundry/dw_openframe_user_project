# Double-wide user project notes

## Architecture

```text
double_wide_openframe (harness, installed as caravel/ by `cf setup`)
  double_wide_chip_io          pad ring + empty wrapper instance
       │ cell swap at integration
       ▼
dw_openframe_user_project
  double_wide_openframe_project_wrapper   your hardened GDS
```

The harness is a pass-through padframe (no management SoC). Besides the 63 GPIO
pads, the frame drives the power-on reset (`porb_h`, `porb_l`, `por_l`), the
master reset from the `resetb` pad (`resetb_h`, `resetb_l`) and per-pad
`gpio_loopback_one` / `gpio_loopback_zero` constants into the wrapper.

## Power domains

The wrapper keeps the OpenFrame multi-domain port names: `vccd1`/`vssd1`,
`vccd2`/`vssd2`, `vdda*`/`vssa*`, `vddio`/`vssio`. Digital logic connects to
**`vccd1`/`vssd1`**. The wrapper is hardened with LibreLane 3
(`openlane/double_wide_openframe_project_wrapper/config.json`,
`meta.version: 3`) as an elaborate-only shell with zero standard cells of its
own -- the same macro+wrapper split `openframe_project_wrapper` uses for
`user_proj_timer` and `user_project_wrapper` uses for `user_proj_example`.

The padframe hands each supply over as met3 straps that end on pad-aligned
power ports at the edge of the user area (listed in `pin_template.def`).
LibreLane's `OpenROAD.GeneratePDN` step builds the met4/met5 grid inside the
core area only, so the wrapper's `pdn_cfg.tcl` (`PDN_CFG`) adds the missing
link after the grid is generated. For every power port of the template it
draws, inside the 40 µm margin between the die edge and the core:

* a met3 strap as wide as the port, from the die edge inward;
* a bar along the edge from the strap to the nearest stripes of the same net
  (met4 on the east/west edges, met3 on the north/south edges, so the signal
  pins on each edge still route underneath);
* a stub extending each of those stripes out over the bar, with via arrays
  at each junction.

`FP_TEMPLATE_COPY_POWER_PINS` restores the template's ports as the wrapper's
power pins, and `PDN_MACRO_CONNECTIONS` stitches the `user_proj_counter`
macro's own power pins into the grid. No metal-only "connection" macro is
needed. `PDN_ENABLE_PINS` alone is not enough: it only labels grid stripes as
pins and never reaches the pad-aligned ports.

## Example design

| GPIO | Role | `CF_gpio_config` mode |
|------|------|------|
| 0 | user clock | input |
| 1 | active-low reset | input with pull-up |
| 13:2 | `count[11:0]` | output |
| 62:14 | unused | analog (input buffer off, high impedance) |

`user_proj_counter` is hardened on its own
(`openlane/user_proj_counter/config.json`) as a dense macro and placed into
the wrapper via a `MACROS` entry, exactly like `user_proj_timer` in
`openframe_project_wrapper` and `user_proj_example` in `user_project_wrapper`.
It resets asynchronously on `rst_n & porb_l & resetb_l` and releases reset
through a two-flop synchronizer, so the asynchronous pad and frame resets
cannot cause recovery/removal violations.

## Timing constraints

The wrapper uses its own SDC for PnR and signoff
(`openlane/double_wide_openframe_project_wrapper/double_wide_openframe_project_wrapper.sdc`):

* Pad-driven inputs use the characterized pad input transition from the Caravel
  signoff constraints (0.38 ns max / 0.05 ns min) instead of a weak
  standard-cell driver.
* Reset inputs are false paths (release is re-timed by the internal
  synchronizer).
* `gpio_loopback_one/zero` are constants (`set_case_analysis`).
* 1.0 ns max-transition limit (Caravel and OpenFrame sign off the wrapper at
  1.5 ns).

## Verification

`cf verify` runs cocotb at chip level through `caravel_cocotb --openframe`: the
testbench top (`caravel/verilog/rtl/toplevel_cocotb.v`) instantiates the full
padframe, so stimulus passes through the sky130 pad models, the frame POR and
the `resetb` pad before reaching the wrapper.

## Precheck

* Wrapper GDS: `gds/double_wide_openframe_project_wrapper.gds`
* Golden root (`-c`): the harness in `caravel/`
* XOR: everything outside the 6754.63 × 4766.63 µm user area must match the
  golden empty wrapper.
* LVS: `lvs/double_wide_openframe_project_wrapper/lvs_config.json` (Magic
  extraction + Netgen against `verilog/gl/double_wide_openframe_project_wrapper.v`).
* OEB: CVC checks the pad configuration of all 63 GPIOs.
