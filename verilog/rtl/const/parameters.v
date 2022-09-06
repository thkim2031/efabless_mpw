  //Parameters
  parameter WIDTH=16; //32 or 64
  parameter CWIDTH=32;
  parameter EXP_WIDTH=8;
  parameter SIG_WIDTH=7;
  parameter CSIG_WIDTH=23;
  parameter BIAS=127;
  
  //localparam ADD_WIDTH=3*(SIG_WIDTH+1)+3;
  localparam SHAMT_WIDTH=6;
     
  //CLA Parameters
 parameter CLA_GRP_WIDTH=12;
 parameter N_CLA_GROUPS=2;
 localparam ADDER_WIDTH=N_CLA_GROUPS*CLA_GRP_WIDTH;
 
 //CSA: WIDTH
 parameter GRP_WIDTH = 24;
  
  
   parameter code_NaN=16'b0_11111111_1000_000;
  parameter code_PINF=16'b0_11111111_0000_000;
  parameter code_NINF=16'b1_11111111_0000_000;