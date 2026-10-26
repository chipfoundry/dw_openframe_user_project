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
 *   GPIO 0      clock input
 *   GPIO 1      active-low reset input with pull-up (also reset by porb_l
 *               and resetb_l)
 *   GPIO 13:2   count[11:0] outputs
 *   GPIO 62:14  unused (analog / high-impedance)
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

    localparam COUNT_WIDTH = 12;
    localparam COUNT_LSB   = 2;
    localparam FIRST_UNUSED = COUNT_LSB + COUNT_WIDTH;

    wire                   clk;
    wire                   rst_n;
    wire [COUNT_WIDTH-1:0] count;

    // user_proj_counter is a plain RTL submodule, synthesized flat together
    // with the wrapper (no separate hardened macro/GDS). LibreLane's PDN
    // generator stitches the wrapper's own power grid straight to the
    // vccd1/vssd1 pad pins (see Wrapper.AddPowerEdgePorts in config.json),
    // so no metal-only bridge cells are needed either.
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
        .gpio_zero(gpio_loopback_zero[0]),
        .gpio_one(gpio_loopback_one[0]),
        .gpio_in(gpio_in[0]),
        .gpio_dm({gpio_dm2[0], gpio_dm1[0], gpio_dm0[0]}),
        .gpio_inp_dis(gpio_inp_dis[0]),
        .gpio_oeb_out(gpio_oeb[0]),
        .gpio_out_val(gpio_out[0]),
        .gpio_analog_en(gpio_analog_en[0]),
        .gpio_analog_sel(gpio_analog_sel[0]),
        .gpio_analog_pol(gpio_analog_pol[0]),
        .gpio_ib_mode_sel(gpio_ib_mode_sel[0]),
        .gpio_vtrip_sel(gpio_vtrip_sel[0]),
        .gpio_slow_sel(gpio_slow_sel[0]),
        .gpio_holdover(gpio_holdover[0])
    );

    CF_gpio_config #(.MODE(3'd3)) gpio_rst_config (
        .io_out(),
        .io_in(rst_n),
        .io_oeb(),
        .gpio_zero(gpio_loopback_zero[1]),
        .gpio_one(gpio_loopback_one[1]),
        .gpio_in(gpio_in[1]),
        .gpio_dm({gpio_dm2[1], gpio_dm1[1], gpio_dm0[1]}),
        .gpio_inp_dis(gpio_inp_dis[1]),
        .gpio_oeb_out(gpio_oeb[1]),
        .gpio_out_val(gpio_out[1]),
        .gpio_analog_en(gpio_analog_en[1]),
        .gpio_analog_sel(gpio_analog_sel[1]),
        .gpio_analog_pol(gpio_analog_pol[1]),
        .gpio_ib_mode_sel(gpio_ib_mode_sel[1]),
        .gpio_vtrip_sel(gpio_vtrip_sel[1]),
        .gpio_slow_sel(gpio_slow_sel[1]),
        .gpio_holdover(gpio_holdover[1])
    );

    genvar i;
    generate
        for (i = 0; i < COUNT_WIDTH; i = i + 1) begin : gpio_count_config
            CF_gpio_config #(.MODE(3'd4)) u_cfg (
                .io_out(count[i]),
                .io_in(),
                .io_oeb(),
                .gpio_zero(gpio_loopback_zero[COUNT_LSB + i]),
                .gpio_one(gpio_loopback_one[COUNT_LSB + i]),
                .gpio_in(gpio_in[COUNT_LSB + i]),
                .gpio_dm({gpio_dm2[COUNT_LSB + i], gpio_dm1[COUNT_LSB + i], gpio_dm0[COUNT_LSB + i]}),
                .gpio_inp_dis(gpio_inp_dis[COUNT_LSB + i]),
                .gpio_oeb_out(gpio_oeb[COUNT_LSB + i]),
                .gpio_out_val(gpio_out[COUNT_LSB + i]),
                .gpio_analog_en(gpio_analog_en[COUNT_LSB + i]),
                .gpio_analog_sel(gpio_analog_sel[COUNT_LSB + i]),
                .gpio_analog_pol(gpio_analog_pol[COUNT_LSB + i]),
                .gpio_ib_mode_sel(gpio_ib_mode_sel[COUNT_LSB + i]),
                .gpio_vtrip_sel(gpio_vtrip_sel[COUNT_LSB + i]),
                .gpio_slow_sel(gpio_slow_sel[COUNT_LSB + i]),
                .gpio_holdover(gpio_holdover[COUNT_LSB + i])
            );
        end

        for (i = FIRST_UNUSED; i < 63; i = i + 1) begin : gpio_unused_config
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
    endgenerate

endmodule

`default_nettype wire
