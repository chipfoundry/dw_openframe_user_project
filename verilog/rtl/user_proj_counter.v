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

// Example user macro: a free-running counter with an active-low reset.
// The reset is the AND of the external reset pin and the frame power-on /
// master resets so the counter starts from zero after power-up and whenever
// resetb_pad is asserted. Reset assertion is asynchronous; release is
// synchronized to clk (two flops) so the counter never sees a reset
// recovery/removal violation from the asynchronous pad inputs.
module user_proj_counter #(
    parameter WIDTH = 12
) (
`ifdef USE_POWER_PINS
    inout  wire             vccd1,
    inout  wire             vssd1,
`endif
    input  wire             clk,
    input  wire             rst_n,
    input  wire             porb_l,
    input  wire             resetb_l,
    output reg  [WIDTH-1:0] count
);

    wire arst_n = rst_n & porb_l & resetb_l;

    reg [1:0] rst_sync;
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            rst_sync <= 2'b00;
        else
            rst_sync <= {rst_sync[0], 1'b1};
    end
    wire srst_n = rst_sync[1];

    always @(posedge clk or negedge srst_n) begin
        if (!srst_n)
            count <= {WIDTH{1'b0}};
        else
            count <= count + 1'b1;
    end

endmodule

`default_nettype wire
