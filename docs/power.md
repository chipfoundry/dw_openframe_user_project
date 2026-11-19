# Power

How `vccd1` and `vssd1` get from the pads to your cells, what the two connection macros do, and when you have to replace them.

## The short version

- Put digital logic on **`vccd1` / `vssd1`**.
- The wrapper carries them on a core ring and a grid. Two fixed macros, `dw_vccd1_connection` and `dw_vssd1_connection`, tie that ring to the pads.
- The flow places those macros. You do not instantiate them, and you keep them when you replace the example.
- If you change the ring or do not use this flow, they no longer fit and you must replace them with your own pad-to-grid connection.

## From pad to cell

```text
vccd1 pad ──> met3 ports on the wrapper's east edge     (frame; pin_template.def)
                    │
          dw_vccd1_connection                           (fixed_dont_change/)
                    │
              vccd1 core ring                           (FP_PDN_CORE_RING_*)
                    │
        met4 / met5 grid stripes                        (FP_PDN_VPITCH, ...)
                    │
          your macro's power pins                       (FP_PDN_MACRO_HOOKS)
```

`vssd1` follows the same path through `dw_vssd1_connection`.

**1. Pad ports.** The frame has one `vccd1` pad and one `vssd1` pad, both on the east edge. Each ends on metal-3 ports at the edge of the user area. Their positions are in `pin_template.def`, and `FP_TEMPLATE_COPY_POWER_PINS` makes them the wrapper's power pins.

**2. Core ring.** Two rings run around the wrapper in the 40 µm margin between the die edge and the core area, on metal 4 (vertical legs) and metal 5 (horizontal legs). Each is 20 µm wide. `vccd1` is the inner ring, `vssd1` the outer.

**3. Grid.** Metal-4 and metal-5 stripes cross the core area and end on the ring. Their pitch, width and offset are the `FP_PDN_V*` / `FP_PDN_H*` settings in the wrapper `config.json`, and they are yours to change.

**4. Macro hooks.** `FP_PDN_MACRO_HOOKS` names, for each macro instance, which grid nets feed which of its power pins.

Steps 1 and 2 do not touch each other: the ports are on metal 3 at the very edge, the ring is on metal 4 a few microns inside. The connection macros close that gap.

## The connection macros

| | `dw_vccd1_connection` | `dw_vssd1_connection` |
| :--- | :--- | :--- |
| Connects | the `vccd1` pad's ports to the inner ring | the `vssd1` pad's ports to the outer ring |
| Placed at (µm, lower-left, orientation N) | (6710.515, 4327.510) | (6710.515, 2088.510) |
| Size | 45.4 × 74.6 µm | 45.4 × 74.6 µm |

Each is two metal-3 plates, one over each of the pad's two ports, with an array of vias down to metal 4 where the plate crosses its ring. They contain no devices. They are the double-wide counterparts of `vccd1_connection` and `vssd1_connection` in `openframe_user_project`.

Files, all in `openlane/double_wide_openframe_project_wrapper/fixed_dont_change/`:

| File | Purpose |
| :--- | :--- |
| `dw_vccd1_connection.gds`, `.lef`, `.mag` | Layout and abstract of the `vccd1` connection |
| `dw_vssd1_connection.gds`, `.lef`, `.mag` | Layout and abstract of the `vssd1` connection |
| `pdn_cfg.tcl` | Builds the ring and grid, then places the two macros at the coordinates above |

And outside that directory:

| File | Purpose |
| :--- | :--- |
| `config.json` → `MACROS` | Loads the two macros' GDS and LEF |
| `config.json` → `FP_PDN_CFG` | Selects `pdn_cfg.tcl` |
| `config.json` → `IGNORE_DISCONNECTED_MODULES` | The macros have no pins, which is expected |
| `verilog/gl/dw_vccd1_connection.v`, `dw_vssd1_connection.v` | Empty modules, so the hardened wrapper netlist compiles |
| `verilog/includes/includes.gl.openframe_user_project` | Lists those two files for gate-level simulation |
| `lvs/.../lvs_config.json` | Lists them for LVS and flattens them |

### How they differ from OpenFrame's

In `openframe_user_project` you instantiate `vccd1_connection` and `vssd1_connection` in the wrapper RTL. Here you do not. `pdn_cfg.tcl` creates and places the two instances while the power grid is generated, so every wrapper has them in the same place whatever its RTL says. That is why they have no `instances` block in `config.json` and no instance in `double_wide_openframe_project_wrapper.v`.

When it works, the wrapper's hardening log contains:

```text
[INFO] Placed 2 power connection macros.
```

If a macro's `MACROS` entry is missing or the core ring is turned off, the flow stops with an error instead of producing a wrapper with no power connection.

## What to keep, what to change

| Keep as shipped | Why |
| :--- | :--- |
| Everything in `fixed_dont_change/` | The macros and their positions match the frame's pad ports |
| `pin_template.def`, `FP_DEF_TEMPLATE`, `FP_TEMPLATE_COPY_POWER_PINS` | Define where the pad ports are |
| `DIE_AREA`, `CORE_AREA` | Set where the ring runs |
| `FP_PDN_CORE_RING`, `FP_PDN_CORE_RING_*` | Set the ring's width, spacing and offset; the macros' vias are positioned for these values |
| `FP_PDN_CFG` | Selects the script that places the macros |
| The two `dw_*_connection` entries under `MACROS` | Load the macros |
| `VDD_NETS` = `vccd1`, `GND_NETS` = `vssd1` | The ring's nets |

| Change freely | |
| :--- | :--- |
| `FP_PDN_VPITCH`, `FP_PDN_HPITCH`, `FP_PDN_VWIDTH`, `FP_PDN_HWIDTH`, `FP_PDN_VOFFSET`, `FP_PDN_HOFFSET`, `FP_PDN_VSPACING`, `FP_PDN_HSPACING` | The grid inside the ring |
| `FP_PDN_MACRO_HOOKS` | One entry per macro of yours |
| Your own entries under `MACROS` | |

## When the connection macros have to be replaced

The macros are a fit for one ring in one place. Replacing the counter with your design, adding macros or retuning the grid does not affect them. These do:

| If you... | Then |
| :--- | :--- |
| change `FP_PDN_CORE_RING_*`, `CORE_AREA` or the ring's layers | the vias no longer land on the ring legs |
| replace `pdn_cfg.tcl` with your own PDN script | nothing places the macros |
| harden the wrapper with a different flow, or draw it by hand (analog and mixed-signal top levels) | nothing builds the ring or places the macros |
| want `vccd1`/`vssd1` distributed some other way than a ring | the macros have nothing to connect to |

In those cases you supply the connection between the pad ports and your power distribution yourself, either by placing the shipped macros' GDS at the coordinates above over a ring of the same geometry, or with your own cell. Whatever you use has to satisfy the following.

1. **Land on the right ports.** These are the `vccd1` and `vssd1` metal-3 ports on the east edge, in wrapper coordinates (µm):

   | Net | Port y range | Pad |
   | :--- | :--- | :--- |
   | `vccd1` | 4327.61 to 4351.56 | `vccd1` pad |
   | `vssd1` | 4353.05 to 4376.36 | `vccd1` pad, middle port |
   | `vccd1` | 4377.81 to 4401.81 | `vccd1` pad |
   | `vssd1` | 2088.61 to 2112.56 | `vssd1` pad |
   | `vccd1` | 2114.05 to 2137.36 | `vssd1` pad, middle port |
   | `vssd1` | 2138.81 to 2162.81 | `vssd1` pad |

   The ports span x = 6754.33 to 6756.63; the wrapper edge is at x = 6754.63.

2. **Do not bridge a pad's middle port.** Each power pad has three ports: two outer ports of its own net and a middle one of the *other* net. A single plate drawn over the whole pad shorts `vccd1` to `vssd1`. The shipped macros use two separate plates per pad for this reason.

3. **Stay inside the ports and inside the boundary.** Metal that runs past a port, outside the user-area boundary, shows up as a difference in the precheck's boundary XOR.

4. **Carry the current.** The whole of your design's `vccd1` current enters through one pad. Use plates and via arrays of the shipped macros' order of size, not a single wire.

5. **Appear in the netlist flow.** If the connection is a cell of its own, give it an empty Verilog module, list that file in `includes.gl.openframe_user_project` and in `LVS_VERILOG_FILES`, and add the cell to `LVS_FLATTEN`, as is done for the shipped macros.

Then confirm with `cf precheck` that the XOR check reports no boundary difference and that LVS matches: LVS is the check that finds an open or shorted supply.

If the frame's pin template changes in a later release, the template's `fixed_dont_change/` and `pin_template.def` change with it. `cf repo update` brings the template's updated files into your project; re-harden the wrapper afterwards.

## The other supplies

`vccd2`/`vssd2`, `vdda`/`vssa`, `vdda1`/`vssa1`, `vdda2`/`vssa2`, `vddio`/`vssio` and `vccd`/`vssd` have no ring, no grid and no connection macro in this template. They exist as metal-3 pins on the wrapper edge beside their pads, as in OpenFrame. To use one, route from those pins to your circuit yourself, and check each pad's ports in `pin_template.def` first: a pad can carry a port of another net, as the `vccd1` and `vssd1` pads do.
