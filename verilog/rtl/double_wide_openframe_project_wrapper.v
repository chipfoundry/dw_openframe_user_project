// SPDX-FileCopyrightText: 2026 ChipFoundry
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

/*
 * double_wide_openframe_project_wrapper
 *
 * User area of the double-wide openframe (6754.63 x 4766.63 um, 63 GPIOs).
 * The module name and port list must stay identical to the harness template
 * (caravel/verilog/rtl/__double_wide_openframe_project_wrapper.v); the pin
 * locations are fixed by
 * openlane/double_wide_openframe_project_wrapper/fixed_dont_change/.
 *
 * Example design: user_proj_counter
 *   GPIO 48     clock input
 *   GPIO 47     active-low reset input with pull-up (also reset by porb_l
 *               and resetb_l)
 *   GPIO 46:35  count[0] on 46 up to count[11] on 35 (outputs)
 *   all others  unused (analog / high-impedance)
 * These are the 14 west-edge pads, beside the frame reset pins.
 */

module double_wide_openframe_project_wrapper (
`ifdef USE_POWER_PINS
    inout vddio,    // Common 3.3V ESD supply
    inout vssio,    // Common ESD ground
    inout vccd,     // Common 1.8V supply
    inout vssd,     // Common digital ground
    inout vdda,     // User area 0 3.3V supply
    inout vssa,     // User area 0 analog ground
    inout vdda1,    // User area 1 3.3V supply
    inout vssa1,    // User area 1 analog ground
    inout vccd1,    // User area 1 1.8V supply
    inout vssd1,    // User area 1 digital ground
    inout vdda2,    // User area 2 3.3V supply
    inout vssa2,    // User area 2 analog ground
    inout vccd2,    // User area 2 1.8V supply
    inout vssd2,    // User area 2 digital ground
`endif

    // Frame power-on / master reset
    input  porb_h,      // power-on reset, sense inverted, 3.3V domain
    input  por_l,       // power-on reset, noninverted, 1.8V domain
    input  porb_l,      // power-on reset, sense inverted, 1.8V domain
    input  resetb_h,    // master reset, sense inverted, 3.3V domain
    input  resetb_l,    // master reset, sense inverted, 1.8V domain

    // User project ID, programmed in the frame's user_id_programming block
    input  [31:0] mask_rev,

    // GPIO data (gpio_in_h is 3.3V domain; everything else is 1.8V)
    input  [62:0] gpio_in,
    input  [62:0] gpio_in_h,
    input  [62:0] gpio_loopback_one,
    input  [62:0] gpio_loopback_zero,
    output [62:0] gpio_out,
    output [62:0] gpio_oeb,
    output [62:0] gpio_inp_dis,

    // GPIO pad configuration (see sky130_fd_io__gpiov2)
    output [62:0] gpio_ib_mode_sel,
    output [62:0] gpio_vtrip_sel,
    output [62:0] gpio_slow_sel,
    output [62:0] gpio_holdover,
    output [62:0] gpio_analog_en,
    output [62:0] gpio_analog_sel,
    output [62:0] gpio_analog_pol,
    output [62:0] gpio_dm0,
    output [62:0] gpio_dm1,
    output [62:0] gpio_dm2,

    // Direct pad connections
    inout  [62:0] analog_io,
    inout  [62:0] analog_noesd_io
);

    // The example uses the 14 pads of the west edge, next to the frame's
    // power-on and master reset pins. GPIO indices run down that edge, from 35
    // at the top to 48 at the bottom, and user_proj_counter's pins run up it,
    // so count[i] is on GPIO COUNT_GPIO0 - i.
    localparam COUNT_WIDTH = 12;
    localparam CLK_GPIO    = 48;
    localparam RST_GPIO    = 47;
    localparam COUNT_GPIO0 = 46;                              // count[0]
    localparam COUNT_GPION = COUNT_GPIO0 - COUNT_WIDTH + 1;   // count[11], GPIO 35

    wire                   clk;
    wire                   rst_n;
    wire [COUNT_WIDTH-1:0] count;

    // user_proj_counter is hardened as its own macro (see
    // openlane/user_proj_counter/) and placed into this wrapper via the
    // MACROS entry in config.json, the same way openframe_project_wrapper
    // places user_proj_timer and user_project_wrapper places
    // user_proj_example. This instantiation is a blackbox stub for
    // synthesis (EXTRA_VERILOG_MODELS reads the macro's hardened
    // gate-level netlist); the wrapper itself is SYNTH_ELABORATE_ONLY and
    // carries no standard cells of its own.
    user_proj_counter mprj (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
`endif
        .clk(clk),
        .rst_n(rst_n),
        .porb_l(porb_l),
        .resetb_l(resetb_l),
        .count(count)
    );

    // CF_gpio_config modes
    // 0: analog
    // 1: input
    // 2: input pull down
    // 3: input pull up
    // 4: output
    // 5: bidirectional

    CF_gpio_config #(.MODE(3'd1)) gpio_clk_config (
        .io_out(),
        .io_in(clk),
        .io_oeb(),
        .gpio_zero(gpio_loopback_zero[CLK_GPIO]),
        .gpio_one(gpio_loopback_one[CLK_GPIO]),
        .gpio_in(gpio_in[CLK_GPIO]),
        .gpio_dm({gpio_dm2[CLK_GPIO], gpio_dm1[CLK_GPIO], gpio_dm0[CLK_GPIO]}),
        .gpio_inp_dis(gpio_inp_dis[CLK_GPIO]),
        .gpio_oeb_out(gpio_oeb[CLK_GPIO]),
        .gpio_out_val(gpio_out[CLK_GPIO]),
        .gpio_analog_en(gpio_analog_en[CLK_GPIO]),
        .gpio_analog_sel(gpio_analog_sel[CLK_GPIO]),
        .gpio_analog_pol(gpio_analog_pol[CLK_GPIO]),
        .gpio_ib_mode_sel(gpio_ib_mode_sel[CLK_GPIO]),
        .gpio_vtrip_sel(gpio_vtrip_sel[CLK_GPIO]),
        .gpio_slow_sel(gpio_slow_sel[CLK_GPIO]),
        .gpio_holdover(gpio_holdover[CLK_GPIO])
    );

    CF_gpio_config #(.MODE(3'd3)) gpio_rst_config (
        .io_out(),
        .io_in(rst_n),
        .io_oeb(),
        .gpio_zero(gpio_loopback_zero[RST_GPIO]),
        .gpio_one(gpio_loopback_one[RST_GPIO]),
        .gpio_in(gpio_in[RST_GPIO]),
        .gpio_dm({gpio_dm2[RST_GPIO], gpio_dm1[RST_GPIO], gpio_dm0[RST_GPIO]}),
        .gpio_inp_dis(gpio_inp_dis[RST_GPIO]),
        .gpio_oeb_out(gpio_oeb[RST_GPIO]),
        .gpio_out_val(gpio_out[RST_GPIO]),
        .gpio_analog_en(gpio_analog_en[RST_GPIO]),
        .gpio_analog_sel(gpio_analog_sel[RST_GPIO]),
        .gpio_analog_pol(gpio_analog_pol[RST_GPIO]),
        .gpio_ib_mode_sel(gpio_ib_mode_sel[RST_GPIO]),
        .gpio_vtrip_sel(gpio_vtrip_sel[RST_GPIO]),
        .gpio_slow_sel(gpio_slow_sel[RST_GPIO]),
        .gpio_holdover(gpio_holdover[RST_GPIO])
    );

    genvar i;
    generate
        for (i = 0; i < COUNT_WIDTH; i = i + 1) begin : gpio_count_config
            CF_gpio_config #(.MODE(3'd4)) u_cfg (
                .io_out(count[i]),
                .io_in(),
                .io_oeb(),
                .gpio_zero(gpio_loopback_zero[COUNT_GPIO0 - i]),
                .gpio_one(gpio_loopback_one[COUNT_GPIO0 - i]),
                .gpio_in(gpio_in[COUNT_GPIO0 - i]),
                .gpio_dm({gpio_dm2[COUNT_GPIO0 - i], gpio_dm1[COUNT_GPIO0 - i], gpio_dm0[COUNT_GPIO0 - i]}),
                .gpio_inp_dis(gpio_inp_dis[COUNT_GPIO0 - i]),
                .gpio_oeb_out(gpio_oeb[COUNT_GPIO0 - i]),
                .gpio_out_val(gpio_out[COUNT_GPIO0 - i]),
                .gpio_analog_en(gpio_analog_en[COUNT_GPIO0 - i]),
                .gpio_analog_sel(gpio_analog_sel[COUNT_GPIO0 - i]),
                .gpio_analog_pol(gpio_analog_pol[COUNT_GPIO0 - i]),
                .gpio_ib_mode_sel(gpio_ib_mode_sel[COUNT_GPIO0 - i]),
                .gpio_vtrip_sel(gpio_vtrip_sel[COUNT_GPIO0 - i]),
                .gpio_slow_sel(gpio_slow_sel[COUNT_GPIO0 - i]),
                .gpio_holdover(gpio_holdover[COUNT_GPIO0 - i])
            );
        end

        for (i = 0; i < 63; i = i + 1) begin : gpio_unused_config
            if (i < COUNT_GPION || i > CLK_GPIO) begin : unused
                CF_gpio_config #(.MODE(3'd0)) u_cfg (
                    .io_out(),
                    .io_in(),
                    .io_oeb(),
                    .gpio_zero(gpio_loopback_zero[i]),
                    .gpio_one(gpio_loopback_one[i]),
                    .gpio_in(gpio_in[i]),
                    .gpio_dm({gpio_dm2[i], gpio_dm1[i], gpio_dm0[i]}),
                    .gpio_inp_dis(gpio_inp_dis[i]),
                    .gpio_oeb_out(gpio_oeb[i]),
                    .gpio_out_val(gpio_out[i]),
                    .gpio_analog_en(gpio_analog_en[i]),
                    .gpio_analog_sel(gpio_analog_sel[i]),
                    .gpio_analog_pol(gpio_analog_pol[i]),
                    .gpio_ib_mode_sel(gpio_ib_mode_sel[i]),
                    .gpio_vtrip_sel(gpio_vtrip_sel[i]),
                    .gpio_slow_sel(gpio_slow_sel[i]),
                    .gpio_holdover(gpio_holdover[i])
                );
            end
        end
    endgenerate

endmodule

`default_nettype wire
