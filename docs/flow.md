# Flow reference

Every step is a `cf` command (`pip install chipfoundry-cli`). There is no Makefile in this repository.

| Step | Command | Needs |
| :--- | :--- | :--- |
| Initialize | `cf init` | |
| Install tools and frame | `cf setup` | Docker, Git |
| Harden | `cf harden <macro>` | Nix |
| Simulate | `cf verify <test>` | Docker |
| Precheck | `cf precheck` | Docker |

## `cf init`

Writes `.cf/project.json` (not committed; it is machine-local). Answer `double_wide` for the project type; it is offered as the default because the wrapper GDS is in `gds/`. Every other command reads the project type from this file, so run it first.

If you are logged in with `cf login`, `cf init` also links the repository to a project on the ChipFoundry platform, or creates one. `cf link` and `cf unlink` change that later.

## `cf setup`

Installs, inside the project directory (all ignored by Git):

| Path | Contents |
| :--- | :--- |
| `caravel/` | The Double-Wide OpenFrame harness: the padframe, the empty reference wrapper, the simulation top level, the datasheet |
| `dependencies/pdks/` | The sky130 PDK |
| `dependencies/timing-scripts/` | Static timing analysis scripts |
| `venv-cocotb/` | The cocotb environment, plus the `chipfoundry/dv:cocotb` Docker image |
| `openlane/.venv/` | LibreLane's Python package |
| | `cf-precheck` |

The directory is called `caravel/` for every project type; here it holds the double-wide frame, not Caravel.

## `cf harden`

```bash
cf harden --list
```

```bash
cf harden user_proj_counter
```

```bash
cf harden double_wide_openframe_project_wrapper
```

Harden macros before the wrapper: the wrapper's `config.json` reads their GDS, LEF, netlist, SPEF and timing libraries.

- **Nix is required.** For `double_wide` projects `cf harden` runs LibreLane from the project's own `flake.nix`, and refuses `--use-docker`.
- **The LibreLane version is the one `flake.nix` pins:** LibreLane 2 (2.4.6, the ChipFoundry `CI2511` release that `openframe_user_project` also uses). The CLI's messages for this project type say "LibreLane 3"; what runs is whatever the flake pins. Both `config.json` files are written for LibreLane 2. Do not edit `flake.nix` or `flake.lock`.
- Each run is kept in `openlane/<macro>/runs/<tag>/`; the final views are copied to `gds/`, `lef/`, `def/`, `mag/`, `lib/`, `spef/`, `verilog/gl/` and `signoff/<macro>/`.

Useful options:

| Option | Effect |
| :--- | :--- |
| `--tag <name>` | Name the run |
| `--from <step>` | Resume a run from a LibreLane step (`--list-from-steps` lists them) |
| `--open-in-klayout`, `--open-in-openroad` | Open the last run's layout |

### What the wrapper run does and does not check

The wrapper is hardened as a shell around your macros (`SYNTH_ELABORATE_ONLY`), with clock-tree synthesis, resizing, fill, tap and decap insertion off, since it has no cells of its own. Routing, antenna, timing, Magic DRC and KLayout DRC run; the reports are in `signoff/double_wide_openframe_project_wrapper/`.

LVS does not run during the wrapper's hardening (`RUN_LVS` is off in its `config.json`). `cf precheck` runs it, with `lvs/double_wide_openframe_project_wrapper/lvs_config.json`. Do not treat a wrapper as finished until the precheck's LVS has passed: it is the check that finds an unpowered macro or a broken supply connection.

### Timing constraints

Each design has one SDC file used for both place-and-route and signoff.

- `openlane/user_proj_counter/user_proj_counter.sdc`
- `openlane/double_wide_openframe_project_wrapper/double_wide_openframe_project_wrapper.sdc`

What they do that you should keep:

- Inputs driven from a pad use the characterized pad transition (0.38 ns max, 0.05 ns min) from the Caravel signoff constraints, not a standard-cell driver.
- `gpio_loopback_one` / `gpio_loopback_zero` are declared constant with `set_case_analysis`.
- The maximum transition is 1.0 ns.

What you adapt: the clock port and period, I/O delays, and the false paths for your own asynchronous inputs.

### Compressed views

The wrapper's GDS and the `.mag` views are tens of megabytes, so they are committed gzipped and their plain versions are in `.gitignore`:

- `gds/double_wide_openframe_project_wrapper.gds.gz`
- `mag/*.mag.gz`

After hardening, compress the new views before you commit:

```bash
make -f caravel/Makefile compress
```

To get the plain files back, for example to open the layout:

```bash
make -f caravel/Makefile uncompress
```

`cf precheck` uncompresses by itself. Macro GDS files such as `gds/user_proj_counter.gds` stay uncompressed, because the wrapper's `config.json` reads them.

## `cf verify`

```bash
cf verify --list
```

```bash
cf verify counter
```

```bash
cf verify counter --sim gl
```

```bash
cf verify --all
```

```bash
cf verify --all --sim gl
```

Tests are cocotb tests in `verilog/dv/cocotb/<test>/`. They run at chip level: the testbench top is the frame's `caravel/verilog/rtl/toplevel_cocotb.v`, which contains the whole padframe with your wrapper inside, so signals pass through the pad models, the power-on reset and the `resetb` pad.

| File | Role |
| :--- | :--- |
| `verilog/dv/cocotb/<test>/<test>.py` | The test |
| `verilog/dv/cocotb/<test>/<test>.yaml` | Its entry for running it alone |
| `verilog/dv/cocotb/cocotb_tests.py` | Imports every test |
| `verilog/dv/cocotb/user_proj_tests/user_proj_tests.yaml` | What `--all` runs at RTL |
| `verilog/dv/cocotb/user_proj_tests/user_proj_tests_gl.yaml` | What `--all --sim gl` runs |
| `verilog/includes/includes.rtl.openframe_user_project` | RTL files compiled |
| `verilog/includes/includes.gl.openframe_user_project` | Gate-level netlists compiled |

`--all` does not discover tests; it runs the two lists. Gate-level simulation needs the hardened netlists in `verilog/gl/`, so harden first.

In a test, `env.drive_gpio(n, v)`, `env.release_gpio(n)` and `env.monitor_gpio(n)` work on GPIOs 0 to 62, and `dut.resetb_tb` is the master reset pad.

## `cf precheck`

```bash
cf precheck
```

It checks your wrapper against the frame in `caravel/`:

| Check | What it verifies |
| :--- | :--- |
| `topcell_check` | The GDS has one top cell, `double_wide_openframe_project_wrapper` |
| `xor` | The wrapper boundary matches the frame's empty wrapper: same size, same pins |
| `lvs` | The layout matches `verilog/gl/double_wide_openframe_project_wrapper.v`, supplies included |
| `oeb` | The pad configuration of all 63 GPIOs |
| `klayout_feol`, `klayout_beol`, `klayout_offgrid`, `klayout_met_min_ca_density`, `klayout_pin_label_purposes_overlapping_drawing`, `klayout_zeroarea` | Manufacturing DRC |
| `pdnmulti`, `metalcheck`, `spike_check`, `illegal_cellname_check` | Further layout checks |
| `magic_drc` | Optional Magic DRC, off by default |

```bash
cf precheck --list-checks
```

```bash
cf precheck --checks xor --checks lvs
```

```bash
cf precheck --skip-checks lvs
```

```bash
cf precheck --magic-drc
```

## Submitting

Commit the hardened views (large ones compressed) and push to GitHub. Then, logged in and with the project linked:

```bash
cf push
```

```bash
cf submit
```

`cf push` uploads the project to ChipFoundry and `cf submit` sends it for review; `cf status` shows where it is. The [ChipFoundry platform](https://platform.chipfoundry.io) has the shuttle schedule and submission details.

## Troubleshooting

| Symptom | Cause and fix |
| :--- | :--- |
| `double_wide hardening does not support --use-docker` | Install Nix and run `cf harden` without the option |
| `Nix not available or cannot resolve the project's ... flake` | Nix is not installed, or it cannot reach the network to fetch the flake |
| `No flake.nix found` | `flake.nix` was deleted. Restore it from the template |
| `harness not found` from `cf precheck`, or missing files under `caravel/` | Run `cf setup` |
| `power connection macro ... is not loaded` during hardening | A `dw_*_connection` entry was removed from `MACROS` in the wrapper `config.json`. Put it back |
| `the power connection macros need the vccd1/vssd1 core ring` | `FP_PDN_CORE_RING` was turned off. Turn it on, or see [power.md](power.md#when-the-connection-macros-have-to-be-replaced) |
| Precheck `xor` reports differences | Something changed the wrapper boundary: an edited `pin_template.def`, a different `DIE_AREA`, or metal drawn past the edge |
| Precheck `lvs` reports `vccd1` shorted to `vssd1` | A power connection covers a pad's middle port. See [power.md](power.md#when-the-connection-macros-have-to-be-replaced) |
| Precheck `lvs` reports a macro's supply open | The macro is missing from `FP_PDN_MACRO_HOOKS`, or no grid stripe crosses it |
| Precheck `oeb` fails | A pad's controls are not driven as the check expects. Make sure each of the 63 pads has exactly one `CF_gpio_config` |
| Gate-level simulation does not compile | A macro's netlist is missing from `includes.gl.openframe_user_project` |
| GitHub rejects or warns about a large file | A plain `.gds` or `.mag` was committed. Compress it ([Compressed views](#compressed-views)) |
