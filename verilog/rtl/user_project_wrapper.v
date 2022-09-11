// SPDX-FileCopyrightText: 2020 Efabless Corporation
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
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

/*--------------------------------------*/
/* User project is instantiated  here   */
/*--------------------------------------*/





    FFPMAC ffpmac_0(
	
//		`ifdef USE_POWER_PINS
//		.vccd1(vccd1),	// User area 1 1.8V power
//		.vssd1(vssd1),	// User area 1 digital ground
//		`endif
	    .A(la_data_in[15:0]),
	    .B(la_data_in[31:16]), 
	    .C(la_data_in[63:32]),
	    .rnd(la_oenb[1:0]),
	    .clk(user_clock2),
	    .rst(wb_rst_i),
	    .result(la_data_out[31:0]));

    CLA_16 cla16_0( 
//		`ifdef USE_POWER_PINS
//		.vccd1(vccd1),	// User area 1 1.8V power
//		.vssd1(vssd1),	// User area 1 digital ground
//		`endif
	    .OPA(la_data_in[79:64]),
	    .OPB(la_data_in[95:80]),
	    .CIN(la_oenb[2]), .PHI(la_oenb[3]),
	    .SUM_FINAL(la_data_out[47:32]),
	    .COUT_FINAL(la_data_out[48]),
	    .CLK(wb_clk_i));
    sa_2D sa2d_0( 
	
//		`ifdef USE_POWER_PINS
//		.vccd1(vccd1),	// User area 1 1.8V power
//		.vssd1(vssd1),	// User area 1 digital ground
//		`endif
	    .AA(la_data_in[103:96]), 
	    .BB(la_data_in[111:104]), 
	    .CLK(wb_clk_i), 
	    .SHIFTEN(la_oenb[5:4]),
	    .RST(wb_rst_i), 
	    .Y(la_data_out[80:49]));
   r8_mb8 r8_mb8_0(
   
//		`ifdef USE_POWER_PINS
//		.vccd1(vccd1),	// User area 1 1.8V power
//		.vssd1(vssd1),	// User area 1 digital ground
//		`endif
	    .mx(la_data_in[119:112]),
	    .my(la_data_in[127:120]),
	    .CLK(wb_clk_i), 
	    .RST(wb_rst_i),
	    .product_final(la_data_out[96:81]));





endmodule	// user_project_wrapper


/*

(* blackbox *)

module FFPMAC(A, B, C, rnd, clk, rst,  result);
//Parameters
`ifdef USE_POWER_PINS
    inout vccd1,        // User area 1 1.8V supply
    inout vssd1,        // User area 1 digital ground
`endif
  parameter WIDTH_16 = 16;
  parameter WIDTH_32 = 32;
 
  //I/O decalarations
  input [WIDTH_16-1:0] A,B;
  input [WIDTH_32-1:0] C;
  input [1:0] rnd;
  input clk, rst;
  output [WIDTH_32-1:0] result;
 
  endmodule

module CLA_16 ( OPA, OPB, CIN, PHI, SUM_FINAL, COUT_FINAL, CLK );

  parameter N_16 = 16;
  `ifdef USE_POWER_PINS
    inout vccd1,        // User area 1 1.8V supply
    inout vssd1,        // User area 1 digital ground
  `endif
  input  [N_16-1:0] OPA;
  input  [N_16-1:0] OPB;
  input  CIN;
  input  PHI;
  input  CLK;
  output [N_16-1:0] SUM_FINAL;
  output COUT_FINAL;

  endmodule

  
module sa_2D( AA, BB, CLK,SHIFTEN ,RST, Y);

  parameter HPE=2;  // step 1 horizontal processing elements
  parameter VPE=2;  // vertical processing elements

  parameter WIDTH_4=4;   // step 2 operands width  
  `ifdef USE_POWER_PINS
    inout vccd1,        // User area 1 1.8V supply
    inout vssd1,        // User area 1 digital ground
  `endif
  input   [WIDTH_4*HPE-1:0]  AA;
  input   [WIDTH_4*HPE-1:0]  BB;
  input           CLK;
  input           RST;
  input   [1:0]      SHIFTEN;
  output   [(2*WIDTH_4*HPE*VPE)-1:0]  Y;

  endmodule


module r8_mb8(mx,my,CLK,RST,product_final);
  parameter WIDTH_8 = 8;
  `ifdef USE_POWER_PINS
    inout vccd1,        // User area 1 1.8V supply
    inout vssd1,        // User area 1 digital ground
  `endif
  //IO Start
  input wire [WIDTH_8-1:0] mx;
  input wire [WIDTH_8-1:0] my;
  input wire CLK;
  input wire RST;
  output reg [(WIDTH_8*2)-1:0] product_final;

  endmodule


module clock_divider(clk,clock_out);
	`ifdef USE_POWER_PINS
//    inout vccd1,        // User area 1 1.8V supply
//    inout vssd1,        // User area 1 digital ground
	`endif
    //IO Start
	input clk;
	input clock_out;
endmodule

*/

`default_nettype wire
