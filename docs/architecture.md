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
**`vccd1`/`vssd1`**. The wrapper is hardened with LibreLane 2
(`openlane/double_wide_openframe_project_wrapper/config.json`) as an
elaborate-only shell with zero standard cells of its own -- the same
macro+wrapper split `openframe_project_wrapper` uses for `user_proj_timer`
and `user_project_wrapper` uses for `user_proj_example`.

Power distribution follows OpenFrame:

* `vccd1` and `vssd1` run on a core ring in the 40 µm margin between the die
  edge and the core area: two 20 µm rings on met4/met5, `vccd1` inside
  `vssd1`. The grid stripes extend to the ring, and `FP_PDN_MACRO_HOOKS` ties
  the `user_proj_counter` macro to the grid.
* The padframe hands each supply over as met3 straps that end on pad-aligned
  ports at the edge of the user area (`pin_template.def`).
  `FP_TEMPLATE_COPY_POWER_PINS` keeps those ports as the wrapper's power pins.
* `dw_vccd1_connection` and `dw_vssd1_connection` bridge the two: each is a
  met3 plate covering one pad's two ports, with via3 arrays onto that
  supply's ring leg (inner leg for `vccd1`, outer leg for `vssd1`). They are
  the double-wide counterparts of OpenFrame's `vccd1_connection` and
  `vssd1_connection`.

The connection macros live in
`openlane/double_wide_openframe_project_wrapper/fixed_dont_change/` together
with `pdn_cfg.tcl`, which places them at fixed locations during
`OpenROAD.GeneratePDN`. They are not part of the RTL and have no placement in
`config.json`, so every hardened wrapper carries them in the same place.

The remaining supplies (`vccd`, `vccd2`, `vdda*`, `vddio` and their grounds)
are edge pins only, as in OpenFrame.

## Example design

| GPIO | Role | `CF_gpio_config` mode |
|------|------|------|
| 48 | user clock | input |
| 47 | active-low reset | input with pull-up |
| 46 down to 35 | `count[0]` up to `count[11]` | output |
| all others | unused | analog (input buffer off, high impedance) |

The example uses the 14 west-edge pads, next to the frame reset pins; GPIO
indices run down that edge.

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
