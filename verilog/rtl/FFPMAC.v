module FFPMAC(A, B, C, rnd, clk, rst,  result);
 //Rounding modes (rnd)
  // 00 -> Round to zero
  // 01 -> Round to nearest
  // 10 -> Round to nearest even
 
  //Parameters
 `include "./const/parameters.v"
  
  //I/O decalarations
  input [WIDTH-1:0] A,B;
  input [CWIDTH-1:0] C;
  // wire [1:0] rnd=1;
  input [1:0] rnd;
  input clk, rst;  
  output reg [CWIDTH-1:0] result;
  //Special cases handling
  wire aIsPZero, bIsPZero, cIsPZero, setResultNaN, setResultPInf,
       aIsNZero, bIsNZero, cIsNZero, setResultNInf;
  fpSpecialCases SCH(A,B,C, aIsPZero, aIsNZero, bIsPZero, bIsNZero, cIsPZero,
                    cIsNZero, setResultNaN, setResultPInf, setResultNInf);
  wire setResultZero = (aIsNZero | aIsPZero | bIsNZero |  bIsPZero ) & (cIsPZero | cIsNZero);    
           
  //Unpacking and subnormal checks
  wire aIsSubnormal, bIsSubnormal, cIsSubnormal;
  wire aSign, bSign, cSign;
  wire [EXP_WIDTH-1:0] aExp, bExp, cExp;
  wire [SIG_WIDTH:0] aSig, bSig;
  wire [CSIG_WIDTH:0] cSig;
  unpack UPCK(A,B,C, aIsSubnormal, aSign, aExp, aSig,
                     bIsSubnormal, bSign, bExp, bSig,
                     cIsSubnormal, cSign, cExp, cSig);
                     
  //Sign handling 
  wire product_sign=aSign ^ bSign;
  wire effectiveOp = cSign ^ product_sign;
  wire [18:0] prodT;

  //Exponent comparison
  wire [SHAMT_WIDTH-1:0] shamt;
  wire [EXP_WIDTH-1:0] resExp1;
  wire cExpIsSmall;
  exponentComparison EC(aExp, bExp, cExp, shamt, cIsSubnormal, resExp1, cExpIsSmall);
  
  //**********Alignment Shift
  wire [2*(SIG_WIDTH+1)+CSIG_WIDTH+7:0] CAligned_pre;//47 btis
  wire [2*(SIG_WIDTH+1)+CSIG_WIDTH+7:0] CAligned; //47bits
  
  
  wire sticky;
  align ALGN(cSig, shamt, CAligned_pre, sticky);
  
  //Bit-invert C for effective subtraction
  assign CAligned = (effectiveOp)?{1'b1,~CAligned_pre[2*(SIG_WIDTH+1)+CSIG_WIDTH+6:0]}:{1'b0,CAligned_pre[2*(SIG_WIDTH+1)+CSIG_WIDTH+6:0]};
  
  
  //Significand multiplier
  wire [2*SIG_WIDTH+3:0] sum_of, carry_of;
  wire [2*(SIG_WIDTH+1)+1:0] sum,carry; //18-bit
  wire [2*(SIG_WIDTH+1)+1:0] sum_custom,carry_custom, carry_custom_pre; //18-bit
  
  significandMultiplier1 SMUL(aSig, bSig, sum_custom, carry_custom_pre);
  assign carry_custom = carry_custom_pre<<1;//Why?
   
   //Assign 18-bit sum and carry vectors for significand multiplier
   assign sum = sum_custom; 
   assign carry = carry_custom;
   assign prodT=sum+carry;
  
  //****************************************************************************************************
  //************************CSA to combine product (sum, product and aligned C)
  //*** 3 groups of aligned C
  //C_low: 2 bits --> Guard and Round bit (sticky bit is kept separate for now)
  //C_mid: 18 bits --> Add to product sum and carry vectors
  //C_hi: 26 bits --> Pass on to the increamenter later 
  
  wire [1:0] C_low = {CAligned[1], CAligned[0]};  
  wire [CSIG_WIDTH:0] C_mid = CAligned[CSIG_WIDTH+2:2];//(23:0 -- 25:2 -- 24-bit)
  wire [2*(SIG_WIDTH+1)+4:0] C_hi = CAligned[2*(SIG_WIDTH+1)+CSIG_WIDTH+7:(CSIG_WIDTH)+3];// [46:26]-- 21 bit, MSB is sign
  
  wire [CSIG_WIDTH:0] sum_add, carry_add;//CSA outputs -- 18-bit
  

  compressor_3_2_group24 ADD({sum,6'b000000}, {carry,6'b000000}, C_mid, sum_add, carry_add); /* 18-bit*/
  
  //*****************************************************************************************************
  //***********************Cout supression for Eac
  wire c_eac; 
  wire smul_no_carry = ~(sum[2*(SIG_WIDTH+1)+1] | carry[2*(SIG_WIDTH+1)+1]);
  wire smul_caligned_carry = smul_no_carry | C_mid[CSIG_WIDTH];
  wire carryin_inc = smul_caligned_carry & c_eac;
  
  //*****************************************************************************************************
  //***********************Increamentor for C_hi
  wire [2*(SIG_WIDTH+1)+4:0] C_hi_inc = C_hi+1'b1;//21-bit, MSB is sign bit
  
  
  //*****************************************************************************************************
  //*********************** EAC adder (18-bit)
  wire cin=0;
  wire [CSIG_WIDTH:0] sum_eac;//18-bit (Kashif: 24-bit)
  wire [CSIG_WIDTH:0] carry_add_wgt = {carry_add[CSIG_WIDTH:0],1'b0}; //discard carry_add MSB
  eac_cla_adder /*24-bit*/ EAC(sum_add , carry_add_wgt, cin, sticky, effectiveOp, sum_eac, c_eac );
    
  wire [CSIG_WIDTH-1:0] sum_small = {sum_add[CSIG_WIDTH-1:0]};//17-bit -- 23 bit
  wire [CSIG_WIDTH-1:0] carry_small = {carry_add[CSIG_WIDTH-2:0],1'b0};// -- 23 bit
  
  //*****************************************************************************************************
  //********************* Leading zero anticipator
  wire [5:0] lza_shamt;
  lza LZA(sum_add, carry_add_wgt, lza_shamt);//24-bit
  

  
  //*****************************************************************************************************
  //*********************** Construct prenormalized result
  wire [2*(SIG_WIDTH+1)+CSIG_WIDTH+7:0] prenormalized, prenormalized_pre;//52:0 -- 53-bit (Kashif: 45:0 -- 46 bits)
  assign prenormalized_pre[1:0] = C_low; //Guard and round bits
  assign prenormalized_pre[CSIG_WIDTH+2:2] = sum_eac; //Sum bits 25:2 = 24-bit
  assign prenormalized_pre[2*(SIG_WIDTH+1)+CSIG_WIDTH+7:CSIG_WIDTH+3] = (carryin_inc)?{C_hi_inc}:{C_hi}; //Increamentor bits 46:20 =21-bit
  
  //Bit-complement in case of negative result 
  assign prenormalized = (prenormalized_pre[2*(SIG_WIDTH+1)+CSIG_WIDTH+3] & effectiveOp)?~prenormalized_pre:prenormalized_pre;
  
  //Also set the result sign as negative if a bit-complement is required
  wire res_sign = (prenormalized_pre[2*(SIG_WIDTH+1)+CSIG_WIDTH+3] & effectiveOp)?1'b1:1'b0;
  
  //*****************************************************************************************************
  //*********************** Normalize result
  wire [(CSIG_WIDTH+1)+2:0] normalized;//26:0 -- 27-bit
  wire exp_correction;
  wire [EXP_WIDTH-1:0] exp_normalized;
  normalizeAndExpUpdate NORMALIZE({prenormalized,sticky}, lza_shamt, cExpIsSmall, shamt, exp_correction, normalized,
                      resExp1, exp_normalized);
  
  wire [CWIDTH-1:0] result_pre;
  
  //Round according to rounding mode
  // 00 -> Round to zero
  
  // 01 -> Round to nearest
  // 10 -> Round to nearest even
rounding round(normalized, res_sign, exp_normalized, rnd, result_pre);

  
  //Select result (setResultNaN, setResultPInf, setResultNInf)
  always @ (*) begin
    casex({setResultZero, setResultNaN, setResultPInf, setResultNInf})
      4'b1xxx: //Zero 
              result = 0;
      4'b1xx: //NaN
              result = {code_NaN,16'h0};
      4'b01x: //Positive Infinity
              result = {code_PINF,16'h0};
      4'b001: //Negative Infinity
              result = {code_NINF,16'h0};
      default: //computed result 
              result = result_pre;
    endcase
  end
endmodule

 
//////////////////////////////////////////////////////////////////////////////////////////////

module unpack(A,B,C, aIsSubnormal, aSign, aExp, aSig,
                     bIsSubnormal, bSign, bExp, bSig,
                     cIsSubnormal, cSign, cExp, cSig);

  //Parameters
  parameter WIDTH=16; //32 or 64
  parameter CWIDTH=32;
  parameter EXP_WIDTH=8;
  parameter SIG_WIDTH=7;
  parameter CSIG_WIDTH=23;


     input [WIDTH-1:0] A,B;
     input [CWIDTH-1:0] C;
     output aIsSubnormal, bIsSubnormal, cIsSubnormal;
     output aSign, bSign, cSign;
     output [EXP_WIDTH-1:0] aExp, bExp, cExp;
     output [SIG_WIDTH:0] aSig, bSig;
     output [CSIG_WIDTH:0] cSig;



     //Unpack sign and exponent bits
     assign aExp = A[WIDTH-2:WIDTH-EXP_WIDTH-1];
     assign bExp = B[WIDTH-2:WIDTH-EXP_WIDTH-1];
     assign cExp = C[CWIDTH-2:CWIDTH-EXP_WIDTH-1];

     assign aSign= A[WIDTH-1];
     assign bSign= B[WIDTH-1];
     assign cSign= C[CWIDTH-1];

     //Check subnormal operands
     assign aIsSubnormal = (aExp==0) & (A[SIG_WIDTH-1:0]!=0);
     assign bIsSubnormal = (bExp==0) & (B[SIG_WIDTH-1:0]!=0);
     assign cIsSubnormal = (cExp==0) & (C[CSIG_WIDTH-1:0]!=0);

     //Unpack significand bits
     assign aSig= (aIsSubnormal)?{1'b0,A[SIG_WIDTH-1:0]}:{1'b1,A[SIG_WIDTH-1:0]};
     assign bSig= (bIsSubnormal)?{1'b0,B[SIG_WIDTH-1:0]}:{1'b1,B[SIG_WIDTH-1:0]};
     assign cSig= (cIsSubnormal)?{1'b0,C[CSIG_WIDTH-1:0]}:{1'b1,C[CSIG_WIDTH-1:0]};

  endmodule


//////////////////////////////////////////////////////////////////////////////////////////////


module fpSpecialCases(A,B,C, aIsPZero, aIsNZero, bIsPZero, bIsNZero, cIsPZero,
                    cIsNZero, setResultNaN, setResultPInf, setResultNInf);
  //Detect FP special cases from input FP operands and raise 
  //relavent flags
  //Parameters
 `include "./const/parameters.v"

  input [WIDTH-1:0] A,B;
  input [CWIDTH-1:0] C;
  output aIsPZero, bIsPZero, cIsPZero;
  output aIsNZero, bIsNZero, cIsNZero;
  output setResultNaN, setResultPInf, setResultNInf;


  //Zero Values
  assign aIsPZero = (A == 0);
  assign bIsPZero = (B == 0);
  assign cIsPZero = (C == 0);
  assign aIsNZero = (A == {1'b1,{(WIDTH-1){1'b0}}});
  assign bIsNZero = (B == {1'b1,{(WIDTH-1){1'b0}}});
  assign cIsNZero = (C == {1'b1,{(CWIDTH-1){1'b0}}});

  //NaN Values  
  wire aNaN, bNaN, cNaN;
  assign aNaN = (A[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (|A[SIG_WIDTH-1:0]);
  assign bNaN = (B[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (|B[SIG_WIDTH-1:0]);
  assign cNaN = (C[CWIDTH-2:CWIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (|C[CSIG_WIDTH-1:0]);

  assign setResultNaN = aNaN | bNaN  | cNaN;

  //Inf Values
  wire aIsPInf, bIsPInf, cIsPInf;
  wire aIsNInf, bIsNInf, cIsNInf;
  assign aIsPInf = (A[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|A[SIG_WIDTH-1:0]) & ~A[WIDTH-1];
  assign bIsPInf = (B[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|B[SIG_WIDTH-1:0]) & ~B[WIDTH-1];
  assign cIsPInf = (C[CWIDTH-2:CWIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|C[CSIG_WIDTH-1:0]) & ~C[CWIDTH-1];

  assign aIsNInf = (A[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|A[SIG_WIDTH-1:0]) & A[WIDTH-1];
  assign bIsNInf = (B[WIDTH-2:WIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|B[SIG_WIDTH-1:0]) & B[WIDTH-1];
  assign cIsNInf = (C[CWIDTH-2:CWIDTH-EXP_WIDTH-1]=={EXP_WIDTH{1'b1}}) & (~|C[CSIG_WIDTH-1:0]) & C[CWIDTH-1];

  assign setResultPInf = aIsPInf | bIsPInf | cIsPInf;
  assign setResultNInf = aIsNInf | bIsNInf | cIsNInf;

endmodule


//////////////////////////////////////////////////////////////////////////////////////////////


module align(C, shamt, CAligned,  sticky);
  //Parameters
 `include "./const/parameters.v"

  input [CSIG_WIDTH:0] C;
  input [SHAMT_WIDTH-1:0] shamt;
//  wire [SHAMT_WIDTH-1:0] shamt_adjusted;
  output [2*(SIG_WIDTH+1)+CSIG_WIDTH+7:0] CAligned;//53-bit, However, I counted 46
  output sticky;

  wire [2*(SIG_WIDTH+1)+2*(CSIG_WIDTH+1):0] T;//65 bits for T when 
///////////////////////////For the OR of first 23 bits  ////////////////////// 
  genvar i;
  generate
    for(i=2*(SIG_WIDTH+1);i<2*(SIG_WIDTH+2)+(CSIG_WIDTH)-1;i=i+1) begin: gen_T
      assign T[i]=|C[i-2*(SIG_WIDTH+1):0];//Or  the bits 16-16=0 till 38-16=22
    end
  endgenerate
  ///////////////////////////For the OR of all bits////////////////////// 
   /*genvar i;
  generate
    for(i=2*(SIG_WIDTH+1)+(CSIG_WIDTH);i<=2*(SIG_WIDTH+1)+2*(CSIG_WIDTH+1);i=i+1) begin: gen_T1
      assign T[i]=|C[CSIG_WIDTH:0];//OR all 24 bits of C
    end
  endgenerate  */


  assign CAligned = {1'b0,C,{(2*(SIG_WIDTH+1)+2+2+2){1'b0}}} >> shamt; //1, 24, 54
  assign sticky = (shamt< 2*(SIG_WIDTH+1)+CSIG_WIDTH+1+ 5)?1'b0:T[shamt];//(it should be 2*(SIG_WIDTH+1)+1+ 5)


endmodule


//////////////////////////////////////////////////////////////////////////////////////////////


module exponentComparison(aExp, bExp, cExp, shamt, cIsSubnormal, res_exp, cExpIsSmall);
    //Parameters
 `include "./const/parameters.v"

  input [EXP_WIDTH-1:0] aExp, bExp, cExp;
  input cIsSubnormal;
  output [SHAMT_WIDTH-1:0] shamt;
  output [EXP_WIDTH-1:0] res_exp;
  output cExpIsSmall;

  wire [EXP_WIDTH-1:0] product_exp;

  wire [SHAMT_WIDTH-1:0] shamt_internal, shamt_pre;

  assign product_exp = aExp + bExp;
  assign shamt_pre = product_exp - BIAS - cExp + (2*SIG_WIDTH+3+6);//only shift of 23, why?It should be 23 bits.
  assign shamt_internal = (cExp > (product_exp - BIAS + (2*SIG_WIDTH+3+6)))?0:shamt_pre;

  assign shamt=(cIsSubnormal)? shamt_internal+1:shamt_internal;

  assign cExpIsSmall = ((product_exp - BIAS) >= cExp);

  assign res_exp= ( cExpIsSmall )?product_exp-BIAS:cExp;//Result exponent

endmodule


/////////////////////////////////////////////////////////////////////////////////////////////

module compressor_3_2_group24 (in1, in2, in3, s, c);
  `include "./const/parameters.v"
  input [GRP_WIDTH-1:0] in1, in2, in3;
  output [GRP_WIDTH-1:0] s, c;


  genvar i;
generate
for (i=0;i<GRP_WIDTH; i=i+1) begin: CSAs_loop
  compressor_3_2 compress(in1[i], in2[i],in3[i], s[i], c[i]);
end
endgenerate
  //Test wire
  //wire [GRP_WIDTH-1:0] sum_in = s + c;
endmodule

module compressor_3_2(in1, in2, in3, s, c);
  input in1, in2, in3;
  output s,c;

  assign c = (in1 & in2) | (in2 & in3) | (in3 & in1);
  assign s = (in1 & in2 & in3) | (in1 & ~in2 & ~in3) |
                                 (~in1 & in2 & ~in3) |
                                 (~in1 & ~in2 & in3);



endmodule

//////////////////////////////////////////////////////////////////////////////////////////////



module eac_cla_adder(in1, in2, cin, sticky, effectiveOperation, sum, cout );

  `include "./const/parameters.v"


  input [ADDER_WIDTH-1:0] in1, in2;//[23:0] -- 24 bit
  input cin;
  input sticky, effectiveOperation;
  output [ADDER_WIDTH-1:0] sum; //[23:0] -- 24 bit
  output cout;

  wire [ADDER_WIDTH-1:0] sum_basic;//[23:0] -- 24 bit
  wire [ADDER_WIDTH-1:0] sum_plus_one;//[23:0] -- 24 bit

  wire [N_CLA_GROUPS-1:0] cout_group_g_p;//[1:0] -- 2 bit
  reg [N_CLA_GROUPS-1:0] cout_group; //[1:0] -- 2 bit
  wire [N_CLA_GROUPS-2:0]  cout_group_mix [N_CLA_GROUPS-1:0]; //[0:0][1:0]
  wire [N_CLA_GROUPS-1:0] cin_group = {cout_group[N_CLA_GROUPS-2:0],cin};// [1:0] -- 2 bit -- ={cout_group[0],cin}
  assign cout = cout_group[N_CLA_GROUPS-1];//cout_group[1]
  wire [N_CLA_GROUPS-1:0] GG, GP_base, GP; //[1:0] -- 2 bit


  eac_cla_group CLA_GRP[N_CLA_GROUPS-1:0](in1, in2, GG, GP_base, sum_basic, sum_plus_one);

  //EAC protection for addition operations and sticky bit handling for subtraction
  assign GP[0] = (GP_base[0] & effectiveOperation & ~sticky);
  assign GP[N_CLA_GROUPS-1:1] = GP_base[N_CLA_GROUPS-1:1];

  //EAC logic
  //-- Rotation wires
  wire [N_CLA_GROUPS-1:0] gg_rotated [N_CLA_GROUPS-1:0];
  wire [N_CLA_GROUPS-1:0] gp_rotated [N_CLA_GROUPS-1:0];

  assign gg_rotated[0] = GG;
  assign gp_rotated[0] = GP;
  genvar i;
  generate
    for(i=0;i<N_CLA_GROUPS-1;i=i+1) begin: eac_gen
      assign gg_rotated[i+1] = {GG[i:0],GG[N_CLA_GROUPS-1:i+1]};
      assign gp_rotated[i+1] = {GP[i:0],GP[N_CLA_GROUPS-1:i+1]};
    end
  endgenerate


  genvar j,k;
  //First handle the generate only and propagate only terms of EAC
  assign cout_group_g_p = gg_rotated[0] | (&gp_rotated[0]);
  generate
    //Now handle the generate-propagate comninition terms 
    for(j=0;j<N_CLA_GROUPS;j=j+1) begin: gen1eaccla
      for(k=0;k<N_CLA_GROUPS-1;k=k+1) begin: gen2eaccla
        assign cout_group_mix[j][k]=((&gp_rotated[j][k:0]) & gg_rotated[(j+1)%N_CLA_GROUPS][k]);
      end
    end
  endgenerate

  //Combine different p and g terms to form cout
  integer t,e;
  always @ (*) begin
    cout_group = cout_group_g_p;
    for(t=0;t<N_CLA_GROUPS;t=t+1) begin
      for(e=0;e<N_CLA_GROUPS-1;e=e+1) begin
        cout_group[t] = cout_group[t] | cout_group_mix[t][e];
      end
    end
  end


  //Select proper sum groups according to carry (cout_group)
  assign  sum[CLA_GRP_WIDTH-1:0] = (cout_group[N_CLA_GROUPS-1])?sum_basic[CLA_GRP_WIDTH-1:0]:
                                                          sum_basic[CLA_GRP_WIDTH-1:0];
  genvar l;
  generate
      for(l=1; l<N_CLA_GROUPS; l=l+1) begin: gen_sum_group
        assign sum[(l+1)*CLA_GRP_WIDTH-1:l*CLA_GRP_WIDTH] = (cout_group[l-1])?sum_plus_one[(l+1)*CLA_GRP_WIDTH-1:l*CLA_GRP_WIDTH]:
                                                           sum_basic[(l+1)*CLA_GRP_WIDTH-1:l*CLA_GRP_WIDTH];
      end
  endgenerate





endmodule


//////////////////////////////////////////////////////////////////////////////////////////////



module eac_cla_group(a, b, GG, GP, s, s_plus_one);
  //End Around Carry adder -- CLA group


  parameter CLA_GRP_WIDTH=12;


  input [CLA_GRP_WIDTH-1:0] a, b;//[11:0] -- 12 bits
  output [CLA_GRP_WIDTH-1:0] s, s_plus_one; //[11:0] -- 12 bits
  output GG, GP; //Group generate and group propagate
  //Generate, propagate vectors
  reg [CLA_GRP_WIDTH-1:0] G, P, sum, sum1; //[11:0] -- 12 bits
  reg [CLA_GRP_WIDTH:0]  carry_in, carry_in1; //[12:0] -- 13 bits

  wire cin;
  assign s = sum;
  assign s_plus_one = sum1;
  assign GG = carry_in[CLA_GRP_WIDTH];
  assign GP = &P;

  integer i;

  always @ (*) begin
     //Propagates, generates
     for(i=0;i<CLA_GRP_WIDTH;i=i+1) begin
        G[i] = a[i] & b[i];
        P[i] = a[i] ^ b[i];

     end

     //Carry
     carry_in[0] = 0;
     for(i=1;i<=CLA_GRP_WIDTH;i=i+1) begin
             carry_in[i]=G[i-1] | (carry_in[i-1] & P[i-1]) ;
     end

     carry_in1[0] = 1;
     for(i=1;i<=CLA_GRP_WIDTH;i=i+1) begin
             carry_in1[i]=G[i-1] | (carry_in1[i-1] & P[i-1]) ;
     end


  end

  //Sum
  always @ (*) begin
    for(i=0;i<CLA_GRP_WIDTH;i=i+1) begin
      sum[i] = carry_in[i] ^ P[i];
      sum1[i] = carry_in1[i] ^ P[i];
    end
  end


endmodule

//////////////////////////////////////////////////////////////////////////////////////////////


module normalizeAndExpUpdate(prenormalized, lza_shamt, cExpIsSmall, shamt, exp_correction, normalized, res_exp, normalized_exp);
  //Parameters
  `include "./const/parameters.v"

  input [2*(SIG_WIDTH+1)+CSIG_WIDTH+8:0] prenormalized;//32-bit (Kashif: 46:0 -- 47 bits)
  input [5:0] lza_shamt, shamt;
  input cExpIsSmall;
  input [EXP_WIDTH-1:0] res_exp;
  output [EXP_WIDTH-1:0] normalized_exp;


  output exp_correction;
  output [(CSIG_WIDTH+1)+2:0] normalized; //27-bit

  wire [2*(SIG_WIDTH+1)+CSIG_WIDTH+8:0] normalized1,normalized2,normalized3;  //51 bit//32-bit (Kashif: 46:0 -- 47 bit)
  //If cExp was small, the top 8 bits only  so add 8
  //to lza_shamt

  wire shamt_portion = (shamt >2*(SIG_WIDTH+1)+4);
  wire [5:0] lza_corrected1 = (shamt_portion)? lza_shamt+(2*(SIG_WIDTH+1)+4) : shamt;
  wire [EXP_WIDTH-1:0] exp_update1 = (shamt_portion)? res_exp-lza_shamt+3+cExpIsSmall-(shamt<=21) : res_exp+1;//(It should be shamt==20)

  //Big shift
  assign normalized1 = prenormalized << lza_corrected1;

  //Correction shamt
  reg [1:0] corr_shamt;
  reg [EXP_WIDTH-1:0] exp_update2;
  always @ * begin
     casex(normalized1[2*(SIG_WIDTH+1)+CSIG_WIDTH+8:2*(SIG_WIDTH+1)+CSIG_WIDTH+8-2])//31:29
       3'b001: begin corr_shamt=2;  exp_update2 = exp_update1 - 2; end//Originally 2
       3'b01x: begin corr_shamt=1; exp_update2 = exp_update1 - 1; end//Originally 1
       3'b000: begin corr_shamt=3; exp_update2 = exp_update1 - 3; end//Originally 3
       default: begin corr_shamt=0; exp_update2 = exp_update1; end//Originally 0
     endcase
  end
  //LZA correction shift
  assign normalized2 = normalized1<< corr_shamt;

  assign normalized = normalized2[2*(SIG_WIDTH+1)+CSIG_WIDTH+8:2*(SIG_WIDTH+1)+5]; //46:20 -- 27-bit
  assign exp_correction = (~normalized1[2*(SIG_WIDTH+1)+CSIG_WIDTH+8]);

  assign normalized_exp = exp_update2;

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////

module rounding(normalized, res_sign, exp_normalized, rnd, result_pre);
  parameter CWIDTH=32;
  parameter CSIG_WIDTH=23;
  parameter EXP_WIDTH=8;


  input [(CSIG_WIDTH+1)+2:0] normalized;//26:0 -- 27-bit
  input [EXP_WIDTH-1:0] exp_normalized;
  input res_sign;
  input [1:0] rnd;

  output [CWIDTH-1:0] result_pre;

  wire G, R, T;
  wire [CSIG_WIDTH+1:0] round_nearest;
  wire [CSIG_WIDTH+1:0] round_zero;
  wire [CSIG_WIDTH+1:0] round_rne;
  reg [CSIG_WIDTH+1:0] rounded;

  assign G = normalized[2];
  assign R = normalized[1];
  assign T = normalized[0];
  wire [CSIG_WIDTH+2:0] preround_rn = {1'b0,normalized[(CSIG_WIDTH+1)+2:2]} + 1'b1;//26:2 -- 25-bit
  assign round_rne = (G & ~(R | T))?/*make L=0*/{preround_rn[CSIG_WIDTH+1:2],1'b0}: preround_rn[CSIG_WIDTH+2:1]/*no change*/;
  assign round_nearest =  preround_rn[CSIG_WIDTH+2:1];
  assign round_zero = normalized[(CSIG_WIDTH+1)+2:3];

  always @(*) begin
    casex(rnd)
      2'b00: rounded = round_zero;
      2'b01: rounded = round_nearest;
      default: rounded = round_rne;
    endcase
  end



  //Renormalize if required
  wire [CSIG_WIDTH:0] renormalized = (rounded[CSIG_WIDTH+1])?rounded[CSIG_WIDTH+1:1]:rounded[CSIG_WIDTH:0];
  wire [EXP_WIDTH-1:0] exp_update2 = (rounded[CSIG_WIDTH+1])?exp_normalized+1:exp_normalized;

  //Pack
  wire [CWIDTH-1:0] result_pre;
  assign result_pre = {res_sign,exp_update2,renormalized[CSIG_WIDTH-1:0]};
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////


module significandMultiplier1 #(parameter WIDTH = 8)(
input [WIDTH-1:0] mx,
input [WIDTH-1:0] my,
output [(WIDTH*2)+1:0] sum,
output [(WIDTH*2)+1:0] carry);

parameter group_cnt=(WIDTH>>1)+1;

wire [group_cnt - 1:0] s;
wire [group_cnt - 1:0] d;
wire [group_cnt - 1:0] n;

wire [WIDTH:0] epp2d[0:group_cnt - 1];
wire [9:0] fpp0;
wire [9:0] fpp1;
wire [9:0] fpp2;
wire [9:0] fpp3;
wire [9:0] fpp4;



/******************** Booth encoding ********************/

                        booth_encoder b_e0(.x({mx[1], mx[0], 1'b0}), .single(s[0]), .double(d[0]), .neg(n[0]));
                        booth_encoder b_e1(.x({mx[3], mx[2], mx[1]}), .single(s[1]), .double(d[1]), .neg(n[1]));
                        booth_encoder b_e2(.x({mx[5], mx[4], mx[3]}), .single(s[2]), .double(d[2]), .neg(n[2]));
                        booth_encoder b_e3(.x({mx[7], mx[6], mx[5]}), .single(s[3]), .double(d[3]), .neg(n[3]));
                        booth_encoder b_e4(.x({1'b0, 1'b0, mx[WIDTH - 1]}), .single(s[4]), .double(d[4]), .neg(n[4]));


/******************** Booth Selector-----Partial Product Generation ********************/
genvar i, j;

generate
    for (j = 0; j < group_cnt; j = j + 1) begin: b_selector
                        booth_selector bs(.double(d[j]), .shifted(1'b0), .single(s[j]), .y(my[0]), .neg(n[j]), .p(epp2d[j][0]));
                        booth_selector bs0(.double(d[j]), .shifted(my[0]), .single(s[j]), .y(my[1]), .neg(n[j]), .p(epp2d[j][1]));
                        booth_selector bs1(.double(d[j]), .shifted(my[1]), .single(s[j]), .y(my[2]), .neg(n[j]), .p(epp2d[j][2]));
                        booth_selector bs2(.double(d[j]), .shifted(my[2]), .single(s[j]), .y(my[3]), .neg(n[j]), .p(epp2d[j][3]));
                        booth_selector bs3(.double(d[j]), .shifted(my[3]), .single(s[j]), .y(my[4]), .neg(n[j]), .p(epp2d[j][4]));
                        booth_selector bs4(.double(d[j]), .shifted(my[4]), .single(s[j]), .y(my[5]), .neg(n[j]), .p(epp2d[j][5]));
                        booth_selector bs5(.double(d[j]), .shifted(my[5]), .single(s[j]), .y(my[6]), .neg(n[j]), .p(epp2d[j][6]));
                        booth_selector bs6(.double(d[j]), .shifted(my[6]), .single(s[j]), .y(my[7]), .neg(n[j]), .p(epp2d[j][7]));
                        booth_selector bs7(.double(d[j]), .shifted(my[7]), .single(s[j]), .y(1'b0), .neg(n[j]), .p(epp2d[j][8]));

end
endgenerate
//Partial Products
assign fpp0 = {~n[0] , epp2d[0]};
assign fpp1 = {~n[1] , epp2d[1]};
assign fpp2 = {~n[2] , epp2d[2]};
assign fpp3 = {~n[3] , epp2d[3]};
assign fpp4 = {~n[4] , epp2d[4]};

//Correction vector
wire [17:0]cv= {9'b010101011,n[4],1'b0,n[3],1'b0,n[2],1'b0,n[1],1'b0,n[0]};


/******************** STAGE 1 of Wallace tree ********************/
wire has00;
wire hac00;
wire has01;
wire hac01;

wire ahas00;
wire ahac00;
wire ahas01;
wire ahac01;

wire has10;
wire hac10;
wire has11;
wire hac11;

wire ahas10;
wire ahac10;
wire ahas11;
wire ahac11;

wire [7:0] fas0;
wire [7:0] fac0;

wire [5:0] fas1;
wire [5:0] fac1;

wire [17:0] st00;
wire [11:0] st01;
wire [13:0] st02;
wire [9:0] st03;


HALF_ADDER ha0s0210(.a(cv[0]), .b(fpp0[0]) , .sum(has00), .cout(hac00));
HALF_ADDER ha0s0311(.a(cv[1]), .b(fpp0[1]) , .sum(has01), .cout(hac01));

HALF_ADDER aha0s0210(.a(cv[10]), .b(fpp1[8]) , .sum(ahas00), .cout(ahac00));
HALF_ADDER aha0s0311(.a(cv[11]), .b(fpp1[9]) , .sum(ahas01), .cout(ahac01));

generate
        for (i = 0; i < 8; i = i + 1) begin:    for_s0
                FULL_ADDER fa000(.a(cv[i + 2]), .b(fpp0[i + 2]), .cin(fpp1[i]), .sum(fas0[i]), .cout(fac0[i]));
        end
endgenerate

HALF_ADDER ha0s0220(.a(fpp2[2]), .b(fpp3[0]) , .sum(has10), .cout(hac10));
HALF_ADDER ha0s0321(.a(fpp2[3]), .b(fpp3[1]) , .sum(has11), .cout(hac11));

HALF_ADDER aha0s0220(.a(fpp3[8]), .b(fpp4[6]) , .sum(ahas10), .cout(ahac10));
HALF_ADDER aha0s0321(.a(fpp3[9]), .b(fpp4[7]) , .sum(ahas11), .cout(ahac11));

generate
        for (i = 0; i < 6; i = i + 1) begin:    for_s1
                FULL_ADDER fa001(.a(fpp2[i + 4]), .b(fpp3[i + 2]), .cin(fpp4[i]), .sum(fas1[i]), .cout(fac1[i]));
        end
endgenerate

assign st00 = {cv[17:12], ahas01,ahas00,fas0, has01, has00};
assign st01 = {ahac01, ahac00,fac0, hac01, hac00};
assign st02 = {fpp4[9:8],ahas11, ahas10, fas1, has11, has10, fpp2[1:0]};
assign st03 = {ahac11, ahac10, fac1, hac11, hac10};

//******************** STAGE 2 of Wallace tree********************//*

wire ha1ss00;
wire ha1ss01;
wire ha1ss02;

wire ha1sc00;
wire ha1sc01;
wire ha1sc02;

wire aha1ss10;
wire aha1ss11;
wire aha1ss12;
wire aha1ss13;
wire aha1ss14;

wire aha1sc10;
wire aha1sc11;
wire aha1sc12;
wire aha1sc13;
wire aha1sc14;

wire [8:0] fa1ss0;
wire [8:0] fa1sc0;

wire [17:0] st10;
wire [16:0] st11;
wire [9:0] st12;

HALF_ADDER ha1s0310(.a(st00[1]), .b(st01[0]) , .sum(ha1ss00), .cout(ha1sc00));
HALF_ADDER ha1s0411(.a(st00[2]), .b(st01[1]) , .sum(ha1ss01), .cout(ha1sc01));
HALF_ADDER ha1s0512(.a(st00[3]), .b(st01[2]) , .sum(ha1ss02), .cout(ha1sc02));

HALF_ADDER aha1s0512(.a(st00[13]), .b(st02[9]) , .sum(aha1ss10), .cout(aha1sc10));
HALF_ADDER aha1s0513(.a(st00[14]), .b(st02[10]) , .sum(aha1ss11), .cout(aha1sc11));
HALF_ADDER aha1s0514(.a(st00[15]), .b(st02[11]) , .sum(aha1ss12), .cout(aha1sc12));
HALF_ADDER aha1s0515(.a(st00[16]), .b(st02[12]) , .sum(aha1ss13), .cout(aha1sc13));
HALF_ADDER aha1s0516(.a(st00[17]), .b(st02[13]) , .sum(aha1ss14), .cout(aha1sc14));

generate
        for (i = 0; i < 9; i = i + 1) begin:    for_s3
                FULL_ADDER fa03(.a(st00[i + 4]), .b(st01[i + 3 ]), .cin(st02[i]), .sum(fa1ss0[i]), .cout(fa1sc0[i]));
        end
endgenerate



assign st10 = {aha1ss14, aha1ss13, aha1ss12, aha1ss11, aha1ss10, fa1ss0, ha1ss02, ha1ss01, ha1ss00, st00[0]};
assign st11 = {aha1sc14, aha1sc13, aha1sc12, aha1sc11, aha1sc10, fa1sc0, ha1sc02, ha1sc01, ha1sc00};

assign st12 = st03;

//******************** STAGE 3 of Wallace tree********************//*
wire ha2ss00;
wire ha2ss01;
wire ha2ss02;
wire ha2ss03;
wire ha2ss04;

wire ha2sc00;
wire ha2sc01;
wire ha2sc02;
wire ha2sc03;
wire ha2sc04;
wire aha2ss00;
wire aha2sc00;

wire [9:0] fa2ss0;
wire [9:0] fa2sc0;

wire [17:0] st20;
wire [14:0] st21;

HALF_ADDER ha2s0410(.a(st10[2]), .b(st11[0]) , .sum(ha2ss00), .cout(ha2sc00));
HALF_ADDER ha2s0511(.a(st10[3]), .b(st11[1]) , .sum(ha2ss01), .cout(ha2sc01));
HALF_ADDER ha2s0612(.a(st10[4]), .b(st11[2]) , .sum(ha2ss02), .cout(ha2sc02));
HALF_ADDER ha2s0713(.a(st10[5]), .b(st11[3]) , .sum(ha2ss03), .cout(ha2sc03));
HALF_ADDER ha2s0614(.a(st10[6]), .b(st11[4]) , .sum(ha2ss04), .cout(ha2sc04));

generate
        for (i = 0; i < 10; i = i + 1) begin:   for_s5
                FULL_ADDER fa05(.a(st10[i + 7]), .b(st11[i + 5 ]), .cin(st12[i]), .sum(fa2ss0[i]), .cout(fa2sc0[i]));
        end
endgenerate
HALF_ADDER ha2s04110(.a(st10[17]), .b(st11[15]) , .sum(aha2ss00), .cout(aha2sc00));

assign st20 = {aha2ss00, fa2ss0, ha2ss04, ha2ss03, ha2ss02, ha2ss01, ha2ss00, st10[1:0]};
assign st21 = {fa2sc0, ha2sc04, ha2sc03, ha2sc02, ha2sc01, ha2sc00};



assign sum=st20;
assign carry={st21,2'b00};

endmodule
/******************** Booth Encoder ********************/
module booth_encoder (x, single, double, neg);

input [2:0]x;

output single;

output  double;

output neg;

wire w0;

wire w1;

assign single = x[0] ^ x[1];

assign neg = x[2];

assign  w0 = ~(x[1] ^ x[2]);

assign  w1 = (x[0] ^ x[1]);

assign double =~(w0|w1);

endmodule

/******************** Booth Selector ********************/
module booth_selector (double, shifted, single, y, neg, p);

input double;

input shifted;

input single;

input y;

input neg;

output p;

assign  p = (neg ^ ((y & single) | (shifted & double)));

endmodule

/******************** 1bit Full Adder ********************/

module FULL_ADDER ( a, b, cin, sum, cout );

input  a;

input  b;

input  cin;

output sum;

output cout;

   wire TMP;

   assign TMP = a ^ b;

   assign sum = TMP ^ cin;

   assign cout =  ~ (( ~ (TMP & cin)) & ( ~ (a & b)));

endmodule

module HALF_ADDER ( a, b, sum, cout );

input  a;

input  b;

output sum;

output cout;

   assign sum = a ^ b;

   assign cout = a & b;

endmodule

///////////////////////////////////////////////////////////////////////////////////////

module lza(opA, opB, ldCount);
  //Parameters
  `include "./const/parameters.v"

  //leading digit anticipator
  localparam m=CSIG_WIDTH;
  input [m:0] opA, opB;
  output reg [5:0] ldCount;

  //Genrate, Propageate and Kill vectors

  wire [m:0] G,T,Z;




  generate
    genvar i;
    for(i=m;i>=0;i=i-1) begin:lzd
      assign G[i]=opA[i] & opB[i];
      assign T[i]=opA[i] ^ opB[i];
      assign Z[i]=~opA[i] & ~opB[i];
    end
  endgenerate


  //Indicator vector
  wire [m:0]f;
  assign f[m]=~T[m] & T[m-1];
  generate
    genvar j;
    for(j=m-1;j>0;j=j-1)begin:indicators
      assign f[j]=(T[j+1] & ( (G[j] & ~Z[j-1]) | (Z[j] & ~G[j-1]) ) ) |
                 (~T[j+1] & ( (Z[j] & ~Z[j-1]) | (G[j] & ~G[j-1]) ) );
    end
  endgenerate

  reg [5:0] normalizeAmt;
  always @ (*) begin
   ldCount = normalizeAmt;
 end


  always @ (*) begin
      casex(f)
      {1'b1,{23{1'bx}}}: normalizeAmt=0;
      {1'b0, 1'b1,{22{1'bx}}}: normalizeAmt=1;
      {1'b0, 2'b1,{21{1'bx}}}: normalizeAmt=2;
      {1'b0, 3'b1,{20{1'bx}}}: normalizeAmt=2+1;
      {1'b0, 4'b1,{19{1'bx}}}: normalizeAmt=3+1;
      {1'b0, 5'b1,{18{1'bx}}}: normalizeAmt=4+1;
      {1'b0, 6'b1,{17{1'bx}}}: normalizeAmt=5+1;
      {1'b0, 7'b1,{16{1'bx}}}: normalizeAmt=6+1;
      {1'b0, 8'b1,{15{1'bx}}}: normalizeAmt=7+1;
      {1'b0, 9'b1,{14{1'bx}}}: normalizeAmt=8+1;
      {1'b0, 10'b1,{13{1'bx}}}: normalizeAmt=9+1;
      {1'b0, 11'b1,{12{1'bx}}}: normalizeAmt=10+1;
      {1'b0, 12'b1,{11{1'bx}}}: normalizeAmt=11+1;
      {1'b0, 13'b1,{10{1'bx}}}: normalizeAmt=12+1;
      {1'b0, 14'b1,{9{1'bx}}}: normalizeAmt=13+1;
      {1'b0, 15'b1,{8{1'bx}}}: normalizeAmt=14+1;
      {1'b0, 16'b1,{7{1'bx}}}: normalizeAmt=15+1;
      {1'b0, 16'b1,{6{1'bx}}}: normalizeAmt=16+1;
      {1'b0, 16'b1,{5{1'bx}}}: normalizeAmt=17+1;
      {1'b0, 16'b1,{4{1'bx}}}: normalizeAmt=18+1;
      {1'b0, 16'b1,{3{1'bx}}}: normalizeAmt=19+1;
      {1'b0, 16'b1,{2{1'bx}}}: normalizeAmt=20+1;
      {1'b0, 16'b1,{1{1'bx}}}: normalizeAmt=21+1;
      24'b1: normalizeAmt=22+1;
    default: normalizeAmt=0;
     endcase
  end


endmodule





