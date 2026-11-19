# Replacing the example with your design

The counter shows the pattern; this page is the list of things to change to put your own design in its place. Read [example_counter.md](example_counter.md) first if you have not.

Throughout, `my_macro` stands for a block of yours. A design can have as many macros as it needs.

## 1. Write the RTL

Put your sources in `verilog/rtl/`. For every block that will be hardened as a macro:

- Declare its supplies as `vccd1` and `vssd1`, inside `` `ifdef USE_POWER_PINS ``, as `user_proj_counter.v` does.
- Treat `porb_l`, `resetb_l` and anything arriving from a pad as asynchronous. Synchronize reset release and any data input that crosses into your clock domain.

## 2. Harden each macro

Create `openlane/my_macro/config.json`. The counter's is a good starting point:

```bash
cp -r openlane/user_proj_counter openlane/my_macro
```

Then, in `openlane/my_macro/`:

| Setting | Set it to |
| :--- | :--- |
| `DESIGN_NAME` | `my_macro` |
| `VERILOG_FILES` | Your RTL files |
| `CLOCK_PORT`, `CLOCK_PERIOD` | Your clock |
| `DIE_AREA` | The block's size. It has to fit in the wrapper's core area, 6674.63 × 4686.63 µm |
| `pin_order.cfg` | Your pins, on the sides facing the pads they connect to |
| the `.sdc` file | Your clock, I/O delays and false paths. Rename it and update `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE` |

Keep `VDD_NETS`/`GND_NETS` as `vccd1`/`vssd1`, `RT_MAX_LAYER` at `met4` (metal 5 is the wrapper's, for the power stripes that feed your macro) and `DIODE_ON_PORTS` at `in`.

```bash
cf harden --list
```

```bash
cf harden my_macro
```

The views are written to `gds/`, `lef/`, `def/`, `lib/`, `spef/`, `mag/`, `verilog/gl/` and `signoff/my_macro/`.

## 3. Edit the wrapper RTL

In `verilog/rtl/double_wide_openframe_project_wrapper.v`, leave the module name and the port list alone and change the body:

1. Replace the `user_proj_counter mprj (...)` instance with your macros. Connect `vccd1` and `vssd1` inside `` `ifdef USE_POWER_PINS ``.
2. Give each pad you use a `CF_gpio_config` with the right `MODE` (1 input, 2 input pull-down, 3 input pull-up, 4 output, 5 bidirectional) and connect its `io_in`, `io_out` and `io_oeb` to your macro. Pick pads on the edge your macro sits next to; the numbering is in [double_wide.md](double_wide.md#gpio-numbering).
3. Change the condition of the `gpio_unused_config` loop so that it covers exactly the pads you do not use. Each of the 63 pads must end up with one `CF_gpio_config`, no more and no fewer.

The wrapper should stay free of logic. If something needs a gate, put it in a macro.

## 4. Edit the wrapper configuration

In `openlane/double_wide_openframe_project_wrapper/config.json`:

**`MACROS`**: remove the `user_proj_counter` entry and add one per macro of yours, with the same fields. Leave `dw_vccd1_connection` and `dw_vssd1_connection` where they are.

```json
"my_macro": {
    "gds": ["dir::../../gds/my_macro.gds"],
    "lef": ["dir::../../lef/my_macro.lef"],
    "nl": ["dir::../../verilog/gl/my_macro.v"],
    "spef": {
        "min_*": ["dir::../../spef/multicorner/my_macro.min.spef"],
        "nom_*": ["dir::../../spef/multicorner/my_macro.nom.spef"],
        "max_*": ["dir::../../spef/multicorner/my_macro.max.spef"]
    },
    "lib": {
        "nom_tt_025C_1v80": ["dir::../../lib/multicorner/my_macro__nom_tt_025C_1v80.lib"]
    },
    "instances": {
        "u_my_macro": {
            "location": [150, 500],
            "orientation": "N"
        }
    }
}
```

- `lib` takes one entry per timing corner; copy the nine from the counter's entry and change the name.
- The key under `instances` is the instance name in the wrapper RTL. `location` is the lower-left corner in µm from the wrapper's origin. Keep macros inside the core area (40 to 6714.63 in x, 40 to 4726.63 in y) so they stay clear of the power ring, and clear of each other.

**`FP_PDN_MACRO_HOOKS`**: this connects a macro's power pins to the wrapper's grid. One entry per instance, in the form `<instance> <power net> <ground net> <macro power pin> <macro ground pin>`:

```json
"FP_PDN_MACRO_HOOKS": [
    "u_my_macro vccd1 vssd1 vccd1 vssd1",
    "u_other vccd1 vssd1 vccd1 vssd1"
]
```

A macro left out of this list is placed but not powered. LVS in `cf precheck` catches it.

**Leave as shipped:** the two `dw_*_connection` entries, `FP_PDN_CFG`, `FP_PDN_CORE_RING_*`, `FP_DEF_TEMPLATE`, `FP_TEMPLATE_*`, `DIE_AREA`, `CORE_AREA`. The reasons are in [power.md](power.md).

**Yours to tune:** the grid (`FP_PDN_VPITCH`, `FP_PDN_HPITCH`, `FP_PDN_VWIDTH`, `FP_PDN_HWIDTH`, the offsets and spacings).

## 5. Edit the wrapper constraints

`openlane/double_wide_openframe_project_wrapper/double_wide_openframe_project_wrapper.sdc` describes the example's clock and reset:

- `create_clock` on `gpio_in[48]`, 25 ns. Point it at your clock pad and period, and add any further clocks.
- `set_false_path` from `gpio_in[47]` and the frame resets. Replace `gpio_in[47]` with your own asynchronous inputs.
- `set_output_delay` on `gpio_out[*]`. Adjust to your timing budget.

Keep the input transition values (they model a pad driving the wire, not a standard cell) and the `set_case_analysis` lines for the loopback constants.

## 6. Update the lists that name the macros

| File | Change |
| :--- | :--- |
| `verilog/includes/includes.rtl.openframe_user_project` | Replace `rtl/user_proj_counter.v` with your RTL files |
| `verilog/includes/includes.gl.openframe_user_project` | Replace `gl/user_proj_counter.v` with your macros' gate-level netlists. Keep the two `dw_*_connection.v` lines and the wrapper |
| `lvs/double_wide_openframe_project_wrapper/lvs_config.json` | In `LVS_VERILOG_FILES`, replace `gl/user_proj_counter.v` with your macros' netlists. Keep the `dw_*_connection` lines in `LVS_VERILOG_FILES` and `LVS_FLATTEN` |

The file names in `verilog/includes/` end in `openframe_user_project` for this project type too; do not rename them.

## 7. Write tests

Each test is a directory `verilog/dv/cocotb/<test>/` with `<test>.py` and `<test>.yaml`, imported in `verilog/dv/cocotb/cocotb_tests.py` and listed in `user_proj_tests/user_proj_tests.yaml` (RTL) and `user_proj_tests_gl.yaml` (gate level). Copy the `counter` test and change it.

Tests see the chip from outside: drive pads with `env.drive_gpio(n, value)`, let go with `env.release_gpio(n)`, read them with `env.monitor_gpio(n)`, and drive the master reset pad through `dut.resetb_tb`.

## 8. Remove the counter

Once nothing refers to it:

```bash
git rm -r openlane/user_proj_counter verilog/rtl/user_proj_counter.v verilog/dv/cocotb/counter signoff/user_proj_counter
```

```bash
git rm def/user_proj_counter.def gds/user_proj_counter.gds lef/user_proj_counter.lef mag/user_proj_counter.mag.gz verilog/gl/user_proj_counter.v 'lib/user_proj_counter.lib' 'lib/multicorner/user_proj_counter__*' 'spef/user_proj_counter.spef' 'spef/multicorner/user_proj_counter.*'
```

Do not remove anything named `dw_vccd1_connection` or `dw_vssd1_connection`.

## 9. Harden the wrapper and check

```bash
cf harden double_wide_openframe_project_wrapper
```

Look for `Placed 2 power connection macros.` in the log. Then:

```bash
cf verify --all
```

```bash
cf verify --all --sim gl
```

```bash
cf precheck
```

Before committing, compress the large views ([flow.md](flow.md#compressed-views)).

## Other kinds of design

- **Logic directly in the wrapper, no macro.** The wrapper configuration is set up for a wrapper with no cells: synthesis, clock tree, resizing, fill, tap and decap insertion are all off. A flat design needs them back on, across 32 mm². The macro route is the supported one.
- **Analog or mixed-signal.** Use `analog_io` / `analog_noesd_io` for pad connections and put the pads concerned in `CF_gpio_config` mode 0. The analog supplies are edge pins without a grid; routing them is up to you. If you lay the wrapper out by hand, see [power.md](power.md#when-the-connection-macros-have-to-be-replaced).
