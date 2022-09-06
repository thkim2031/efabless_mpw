`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: INU
// Engineer: Kashif Inayat
// 
// Create Date: 07/17/2020 03:05:23 PM
// Design Name: 
// Module Name: CLA_16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CLA_16 ( OPA, OPB, CIN, PHI, SUM_FINAL, COUT_FINAL, CLK );
`include "./const/parameters_cla.v"

input  [N_16-1:0] OPA;
input  [N_16-1:0] OPB;
input  CIN;
input  PHI;
input  CLK;
output [N_16-1:0] SUM_FINAL;
output COUT_FINAL;

   wire [N_16-1:0] INTPROP;
   wire [N_16:0] INTGEN;
   wire [0:0] PBIT;
   wire [N_16:0] CARRY;
   wire [N_16-1:0] SUM;
   wire COUT;
	
   PRESTAGE_16 U1 (OPA , OPB , CIN , PHI , INTPROP , INTGEN );
   DBLCTREE_16 U2 (INTPROP , INTGEN , PHI , CARRY , PBIT );
   XORSTAGE_16 U3 (OPA[N_16-1:0] , OPB[N_16-1:0] , PBIT , PHI , CARRY[N_16:0] , SUM , COUT );
   
   always@(posedge CLK) begin
	SUM_FINAL <= SUM;
	COUT_FINAL <= COUT;
	end
   
   
endmodule

//******************** Initial Generate and Propagate bits ********************//
module PRESTAGE_16 ( A, B, CIN, PHI, POUT, GOUT );
`include "./const/parameters_cla.v"

input  [N_16-1:0] A;
input  [N_16-1:0] B;
input  CIN;
input  PHI;
output [N_16-1:0] POUT;
output [N_16:0] GOUT;


INVBLOCK U2 (CIN , PHI , GOUT[0] );
genvar i;
  generate
  for(i=0;i<=N_16-1;i=i+1) begin: gen_prop
  BLOCK0 U(A[i] , B[i] , PHI , POUT[i] , GOUT[i+1] );
  end
  endgenerate
 
endmodule
//******************** Carry Look Ahead Adder Tree ********************//
module DBLCTREE_16 ( PIN, GIN, PHI, GOUT, POUT );
`include "./const/parameters_cla.v"

input  [N_16-1:0] PIN;
input  [N_16:0] GIN;
input  PHI;
output [N_16:0] GOUT;
output [0:0] POUT;


   wire [N_16-2:0] INTPROP_0;
   wire [N_16:0] INTGEN_0;
   wire [N_16-4:0] INTPROP_1;
   wire [N_16:0] INTGEN_1;
   wire [N_16-8:0] INTPROP_2;
   wire [N_16:0] INTGEN_2;
//   wire [0:N-16] INTPROP_3;
//   wire [0:N] INTGEN_3;
//   wire [0:N-32] INTPROP_4;
//   wire [0:N] INTGEN_4;
   //wire [8:0] INTPROP_3;
   //wire [24:0] INTGEN_3;
  
   DBLC_0_16 U_0 (.PIN(PIN) , .GIN(GIN) , .PHI(PHI) , .POUT(INTPROP_0) , .GOUT(INTGEN_0) );   
   DBLC_1_16 U_1 (.PIN(INTPROP_0) , .GIN(INTGEN_0) , .PHI(PHI) , .POUT(INTPROP_1) , .GOUT(INTGEN_1) );
   DBLC_2_16 U_2 (.PIN(INTPROP_1) , .GIN(INTGEN_1) , .PHI(PHI) , .POUT(INTPROP_2) , .GOUT(INTGEN_2) );
   DBLC_3_16 U_3 (.PIN(INTPROP_2) , .GIN(INTGEN_2) , .PHI(PHI) , .POUT(POUT) , .GOUT(GOUT) );
   //DBLC_4_32 U_4 (.PIN(INTPROP_3) , .GIN(INTGEN_3) , .PHI(PHI) , .POUT(POUT) , .GOUT(GOUT) );
endmodule

module DBLC_0_16 ( PIN, GIN, PHI, POUT, GOUT );
`include "./const/parameters_cla.v"

input  [N_16-1:0] PIN;
input  [N_16:0] GIN;
input  PHI;
output [N_16-2:0] POUT;
output [N_16:0] GOUT;
INVBLOCK U10 (GIN[0] , PHI , GOUT[0] );
BLOCK1A U21 (PIN[0] , GIN[0] , GIN[1] , PHI , GOUT[1] );
genvar j;
  generate
  for(j=0;j<=N_16-2;j=j+1) begin: gen_prop
  BLOCK1 U32 (PIN[j] , PIN[j+1] , GIN[j+1] , GIN[j+2] , PHI , POUT[j] , GOUT[j+2] );
  end
  endgenerate
endmodule


module DBLC_1_16 ( PIN, GIN, PHI, POUT, GOUT );
`include "./const/parameters_cla.v"

input  [N_16-2:0] PIN;
input  [N_16:0] GIN;
input  PHI;
output [N_16-4:0] POUT;
output [N_16:0] GOUT;
   INVBLOCK U10 (GIN[0] , PHI , GOUT[0] );
   INVBLOCK U11 (GIN[1] , PHI , GOUT[1] );
   BLOCK2A U22 (PIN[0] , GIN[0] , GIN[2] , PHI , GOUT[2] );
   BLOCK2A U23 (PIN[1] , GIN[1] , GIN[3] , PHI , GOUT[3] );
  genvar k;
  generate
  for(k=0;k<=N_16-4;k=k+1) begin: gen_prop
  BLOCK2 U(PIN[k] , PIN[k+2] , GIN[k+2] , GIN[k+4] , PHI , POUT[k] , GOUT[k+4] );
  end
  endgenerate
  endmodule


module DBLC_2_16 ( PIN, GIN, PHI, POUT, GOUT );
`include "./const/parameters_cla.v"

input  [N_16-4:0] PIN;
input  [N_16:0] GIN;
input  PHI;
output [N_16-8:0] POUT;
output [N_16:0] GOUT;
   INVBLOCK U10 (GIN[0] , PHI , GOUT[0] );
   INVBLOCK U11 (GIN[1] , PHI , GOUT[1] );
   INVBLOCK U12 (GIN[2] , PHI , GOUT[2] );
   INVBLOCK U13 (GIN[3] , PHI , GOUT[3] );
   BLOCK1A U24 (PIN[0] , GIN[0] , GIN[4] , PHI , GOUT[4] );
   BLOCK1A U25 (PIN[1] , GIN[1] , GIN[5] , PHI , GOUT[5] );
   BLOCK1A U26 (PIN[2] , GIN[2] , GIN[6] , PHI , GOUT[6] );
   BLOCK1A U27 (PIN[3] , GIN[3] , GIN[7] , PHI , GOUT[7] );
   
  
  genvar l;
  generate
  for(l=0;l<=N_16-8;l=l+1) begin: gen_prop
  BLOCK2 U(PIN[l] , PIN[l+4] , GIN[l+4] , GIN[l+8] , PHI , POUT[l] , GOUT[l+8] );
  end
  endgenerate
  endmodule
  
module DBLC_3_16( PIN, GIN, PHI, POUT, GOUT );
`include "./const/parameters_cla.v"

input  [N_16-8:0] PIN;
input  [N_16:0] GIN;
input  PHI;
output [0:0] POUT;
output [N_16:0] GOUT;
   INVBLOCK U10 (GIN[0] , PHI , GOUT[0] );
   INVBLOCK U11 (GIN[1] , PHI , GOUT[1] );
   INVBLOCK U12 (GIN[2] , PHI , GOUT[2] );
   INVBLOCK U13 (GIN[3] , PHI , GOUT[3] );
   INVBLOCK U14 (GIN[4] , PHI , GOUT[4] );
   INVBLOCK U15 (GIN[5] , PHI , GOUT[5] );
   INVBLOCK U16 (GIN[6] , PHI , GOUT[6] );
   INVBLOCK U17 (GIN[7] , PHI , GOUT[7] );
   BLOCK2A U28 (PIN[0] , GIN[0] , GIN[8] , PHI , GOUT[8] );
   BLOCK2A U29 (PIN[1] , GIN[1] , GIN[9] , PHI , GOUT[9] );
   BLOCK2A U210 (PIN[2] , GIN[2] , GIN[10] , PHI , GOUT[10] );
   BLOCK2A U211 (PIN[3] , GIN[3] , GIN[11] , PHI , GOUT[11] );
   BLOCK2A U212 (PIN[4] , GIN[4] , GIN[12] , PHI , GOUT[12] );
   BLOCK2A U213 (PIN[5] , GIN[5] , GIN[13] , PHI , GOUT[13] );
   BLOCK2A U214 (PIN[6] , GIN[6] , GIN[14] , PHI , GOUT[14] );
   BLOCK2A U215 (PIN[7] , GIN[7] , GIN[15] , PHI , GOUT[15] );   
   BLOCK1 U(PIN[0] , PIN[N_16/2] , GIN[N_16/2] , GIN[N_16] , PHI , POUT[0] , GOUT[N_16] );
endmodule

//******************** XOR STAGE TO GET FINAL SUM bits********************//
module XORSTAGE_16 ( A, B, PBIT, PHI, CARRY, SUM, COUT );
`include "./const/parameters_cla.v"


input  [N_16-1:0] A;
input  [N_16-1:0] B;
input  PBIT;
input  PHI;
input  [N_16:0] CARRY;
output [N_16-1:0] SUM;
output COUT;

 genvar l;
  generate
  for(l=0;l<=N_16-1;l=l+1) begin: f_sum
   XXOR1 U20 (A[l] , B[l] , CARRY[l] , PHI , SUM[l] );
  end
  endgenerate
  
   BLOCK1A U1 (PBIT , CARRY[0] , CARRY[N_16] , PHI , COUT );
endmodule
module INVBLOCK ( GIN, PHI, GOUT );
input  GIN;
input  PHI;
output GOUT;
   assign GOUT =   GIN;
endmodule


module XXOR1 ( A, B, GIN, PHI, SUM );
input  A;
input  B;
input  GIN;
input  PHI;
output SUM;
   assign SUM = (  (A ^ B)) ^ GIN;
endmodule


module BLOCK0 ( A, B, PHI, POUT, GOUT );
input  A;
input  B;
input  PHI;
output POUT;
output GOUT;
   assign POUT =   (A | B);
   assign GOUT =   (A & B);
endmodule


module BLOCK1 ( PIN1, PIN2, GIN1, GIN2, PHI, POUT, GOUT );
input  PIN1;
input  PIN2;
input  GIN1;
input  GIN2;
input  PHI;
output POUT;
output GOUT;
   assign POUT =   (PIN1 & PIN2);
   assign GOUT =  (GIN2 | (PIN2 & GIN1));
endmodule


module BLOCK2 ( PIN1, PIN2, GIN1, GIN2, PHI, POUT, GOUT );
input  PIN1;
input  PIN2;
input  GIN1;
input  GIN2;
input  PHI;
output POUT;
output GOUT;
   assign POUT =   (PIN1 & PIN2);
   assign GOUT =   (GIN2 | (PIN2 & GIN1));
endmodule


module BLOCK1A ( PIN2, GIN1, GIN2, PHI, GOUT );
input  PIN2;
input  GIN1;
input  GIN2;
input  PHI;
output GOUT;
   assign GOUT = (GIN2 | (PIN2 & GIN1));
endmodule


module BLOCK2A ( PIN2, GIN1, GIN2, PHI, GOUT );
input  PIN2;
input  GIN1;
input  GIN2;
input  PHI;
output GOUT;
   assign GOUT =   (GIN2 | (PIN2 & GIN1));
endmodule
