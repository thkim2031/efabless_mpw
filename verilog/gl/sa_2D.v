`timescale 1ns / 10ps
module sa_2D( AA, BB, CLK,SHIFTEN ,RST, Y);

parameter HPE=2;  // step 1 horizontal processing elements
parameter VPE=2;  // vertical processing elements

parameter WIDTH=4;   // step 2 operands width  
`define P_W 8        // outputs width  
`define M_W 4        // width 
parameter group_cnt=(WIDTH>>2)+1;     // no of groups

input   [WIDTH*HPE-1:0]  AA;
input   [WIDTH*HPE-1:0]  BB;
input           CLK;
input           RST;
input 	[1:0]	   SHIFTEN;
output   [(2*WIDTH*HPE*VPE)-1:0]  Y;

wire [WIDTH-1:0] Ain[0:HPE-1];
wire [WIDTH-1:0] Bin[0:HPE-1];

genvar z;
  generate for (z = 0; z < HPE; z = z+1) begin:Input_weights 
      assign Ain[z] = AA[(((z+1)*WIDTH)-1) : ((z)*WIDTH)];
      assign Bin[z] = BB[(((z+1)*WIDTH)-1) : ((z)*WIDTH)];
end
endgenerate


wire [group_cnt - 1:0] S [0:VPE-1][0:HPE-1];
wire [group_cnt - 1:0] D [0:VPE-1][0:HPE-1];
wire [group_cnt - 1:0] T [0:VPE-1][0:HPE-1];
wire [group_cnt - 1:0] Q [0:VPE-1][0:HPE-1];
wire [group_cnt - 1:0] N [0:VPE-1][0:HPE-1];



wire [WIDTH-1:0] MY_OUT[0:VPE-1][0:HPE-1];

wire [WIDTH+1:0] TMY[0:VPE-1][0:HPE-1];

wire [WIDTH*2-1:0] Y_OUT[0:VPE-1][0:HPE-1];
reg [0:HPE-1]D_SHIFTEN;
wire  SHIFTEN_OUT [0:HPE-1][0:HPE-1];

//genvar i,j;
/*
generate
    for (j = 0; j < HPE; j = j + 1) begin: outputs
        for (i = 0; i < VPE; i = i + 1) begin : outputsss
         assign Y[((((HPE*VPE)-((j*HPE)+i))*(WIDTH*2))-1) : ((((HPE*VPE)-((j*HPE)+(i+1)))*(WIDTH*2)))]=Y_OUT[j][i];
        end
        end
endgenerate    
*/
assign Y[31:24]=Y_OUT[0][0];
assign Y[23:16]=Y_OUT[0][1];
assign Y[15:8]=Y_OUT[1][0];
assign Y[7:0]=Y_OUT[1][1];

wire [group_cnt - 1:0] s [0:HPE-1];
wire [group_cnt - 1:0] d [0:HPE-1];
wire [group_cnt - 1:0] t [0:HPE-1];
wire [group_cnt - 1:0] q [0:HPE-1];
wire [group_cnt - 1:0] n [0:HPE-1];

genvar l;
generate
	for (l = 0; l < HPE; l = l + 1) begin: pre_pro1
    pre_process_be pre_pro_be(.mx(Ain[l]), .CLK(CLK), .sr(s[l]), .dr(d[l]), .tr(t[l]), .qr(q[l]), .nr(n[l]));
    end
endgenerate    


genvar k;
generate
	for (k = 0; k < HPE; k = k + 1) begin: pre_process
    sa_pre_process_TMY prep00(.my(Bin[k]), .CLK(CLK), .RST(RST), .my_out(MY_OUT[k][0]), .TMY(TMY[k][0])); 	
    end
endgenerate        





PE_OS_16_R8 PE00( .s(s[0]), .d(d[0]), .t(t[0]), .q(q[0]), .n(n[0]), .Y(MY_OUT[0][0]), .TMY(TMY[0][0]), .CLK(CLK),
 .RST(RST),.SHIFTEN(D_SHIFTEN[0]),.SHIFTV(8'b0),.S_OUT(S[0][0]), .D_OUT(D[0][0]), .T_OUT(T[0][0]), .Q_OUT(Q[0][0]),
  .N_OUT(N[0][0]), .Y_OUT(MY_OUT[0][1]), .TMY_OUT(TMY[0][1]), .MAC_OUT(Y_OUT[0][0]),.SHIFTEN_OUT(SHIFTEN_OUT[0][0]));

PE_OS_16_R8 PE1111( .s(s[1]), .d(d[1]), .t(t[1]), .q(q[1]), .n(n[1]), .Y(MY_OUT[0][1]), .TMY(TMY[0][1]), .CLK(CLK),
 .RST(RST),.SHIFTEN(D_SHIFTEN[1]),.SHIFTV(8'b0),.S_OUT(S[1][0]), .D_OUT(D[1][0]), .T_OUT(T[1][0]), .Q_OUT(Q[1][0]),
  .N_OUT(N[1][0]), .Y_OUT(), .TMY_OUT(), .MAC_OUT(Y_OUT[1][0]), .SHIFTEN_OUT(SHIFTEN_OUT[1][0]) );

PE_OS_16_R8 PEyy( .s(S[0][0]), .d(D[0][0]), .t(T[0][0]), .q(Q[0][0]), .n(N[0][0]), .Y(MY_OUT[1][0]), .TMY(TMY[1][0]),
 .CLK(CLK), .RST(RST),.SHIFTEN(SHIFTEN_OUT[0][0]),.SHIFTV(Y_OUT[0][0]),.S_OUT(S[0][1]), .D_OUT(D[0][1]), .T_OUT(T[0][1]),
  .Q_OUT(Q[0][1]), .N_OUT(N[0][1]), .Y_OUT(MY_OUT[1][1]), .TMY_OUT(TMY[1][1]), .MAC_OUT(Y_OUT[0][1]),.SHIFTEN_OUT(SHIFTEN_OUT[0][1]) );

PE_OS_16_R8 PEzz( .s(S[1][0]), .d(D[1][0]), .t(T[1][0]), .q(Q[1][0]), .n(N[1][0]), .Y(MY_OUT[1][1]), .TMY(TMY[1][1]),
.CLK(CLK), .RST(RST),.SHIFTEN(SHIFTEN_OUT[1][0]),.SHIFTV(Y_OUT[1][0]),.S_OUT(S[1][1]), .D_OUT(D[1][1]), .T_OUT(T[1][1]),
 .Q_OUT(Q[1][1]), .N_OUT(N[1][1]), .Y_OUT(), .TMY_OUT(), .MAC_OUT(Y_OUT[1][1]),.SHIFTEN_OUT(SHIFTEN_OUT[1][1]) );


  
always @(posedge CLK) // one cycle delay as operands have in tmy and be
begin  
  D_SHIFTEN <= SHIFTEN;
end
  
  
  
  
endmodule

/*
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
*/

module sa_pre_process_TMY #(parameter WIDTH = 4)(
input [WIDTH-1:0] my,
input CLK,
input RST,
output reg [WIDTH-1:0] my_out,
output reg [WIDTH+1:0] TMY);
`define TMY_W 10        // outputs width  
`define M_W 8        // width 
//wire [WIDTH:0] OPA;
//wire [WIDTH:0] OPB;
wire [WIDTH+1:0] SUM;
//wire CIN;
//wire PHI;
//assign CIN=1'b0;
//assign PHI=1'b0;

//assign OPA={my,1'b0}; 
//assign OPB={1'b0,my}; 
//assign SUM[0]=OPB[0];
assign SUM=my+(my<<1);

//DBLCADDER_16_16 D (.OPA(OPA[WIDTH:1]) , .OPB(OPB[WIDTH:1]) , .CIN (CIN) , .PHI (PHI) , .SUM(SUM[WIDTH:1]), .COUT(SUM[`M_W+1]) );

always @(posedge CLK) // or negedge RST )
begin
/*
if(RST==1'b0)
begin
         TMY<=`TMY_W'h0;
         my_out<=`M_W'h0;
end
else
begin
*/
         TMY<=SUM;
         my_out<=my;
//end
end

endmodule

module pre_process_be #(parameter WIDTH = 4)(mx, CLK, sr, dr, tr, qr, nr);
    
parameter group_cnt=(WIDTH>>2)+1; 

input [WIDTH-1:0] mx;
input CLK;
output reg [group_cnt - 1:0]sr;
output reg [group_cnt - 1:0]dr;
output reg [group_cnt - 1:0]tr;
output reg [group_cnt - 1:0]qr;
output reg [group_cnt - 1:0]nr;

wire [group_cnt - 1:0]s, d, t, q, n;


//Booth Encoding
			sa_booth3_encoder b_e0(.x({mx[2], mx[1], mx[0], 1'b0}), .single(s[0]), .double(d[0]), .triple(t[0]), .quad(q[0]), .neg(n[0]));
			sa_booth3_encoder b_e1(.x({1'b0, 1'b0, mx[3], mx[2]}), .single(s[1]), .double(d[1]), .triple(t[1]), .quad(q[1]), .neg(n[1]));
//			booth_encoder b_e1(.x({mx[5] ,mx[4], mx[3], mx[2]}), .single(s[1]), .double(d[1]), .triple(t[1]), .quad(q[1]), .neg(n[1]));

//			booth_encoder b_e2(.x({1'b0, mx[WIDTH - 1:WIDTH-3]}), .single(s[2]), .double(d[2]), .triple(t[2]), .quad(q[2]), .neg(n[2]));
			    
always@(posedge CLK)
begin
sr<=s;
dr<=d;
tr<=t;
qr<=q;
nr<=n;
end
endmodule

/******************** Booth Encoder ********************/
module sa_booth3_encoder (x, single, double, triple, quad, neg);

input [3:0]x;

output single;

output  double;

output triple;

output  quad;

output neg;

wire w0;

wire w1;

wire w2;

wire w3;

wire w4;

wire w5;

assign neg=x[3];

assign w0=x[0]^x[1];

assign w1=x[1]^x[2];

assign w2=x[2]^x[3];

assign single=~((~w0)|w2);

assign double=~((~w1)|w0);

assign triple=~((~w2)|(~w0));

assign quad=~((~w2)|(w0|w1));

endmodule


////////////////////////////////////////////////////////////////////////////////////////////



module PE_OS_16_R8( s, d, t, q, n, Y, TMY, CLK, RST,SHIFTEN,SHIFTV, S_OUT, D_OUT, T_OUT, Q_OUT, N_OUT, Y_OUT, TMY_OUT, MAC_OUT,SHIFTEN_OUT);

parameter WIDTH=4;
//`define GC (WIDTH>>2)+1
`define MAC_W 8
parameter group_cnt=(WIDTH>>2)+1;

input [group_cnt - 1:0] s, d, t, q, n;

input   [WIDTH-1:0]  Y;

input   [WIDTH+1:0]  TMY;

input           CLK;

input           RST;
input                   SHIFTEN;
input [2*WIDTH-1:0] SHIFTV;



output [group_cnt - 1:0]S_OUT, D_OUT, T_OUT, Q_OUT, N_OUT;

output  [WIDTH-1:0]  Y_OUT;

output  [WIDTH+1:0]  TMY_OUT;
output reg                      SHIFTEN_OUT;
output [2*WIDTH-1:0]  MAC_OUT;

wire [2*WIDTH-1:0]  MAC_OUT_FB;


reg [2*WIDTH-1:0]  MAC_OUT_BUF0;//Buffer zero
reg [2*WIDTH-1:0]  MAC_OUT_BUF1;//Buffer one
reg TEMP_SHIFT;





reg [group_cnt - 1:0]S_OUT, D_OUT, T_OUT, Q_OUT, N_OUT;

reg   [WIDTH-1:0]  Y_OUT;

reg   [WIDTH+1:0]  TMY_OUT;

wire     [2*WIDTH-1:0]  product;

always @(posedge CLK)
begin

           S_OUT <= s;

           D_OUT <= d;

           T_OUT <= t;

           Q_OUT <= q;

           N_OUT <= n;

           Y_OUT <= Y;

           TMY_OUT <= TMY;
end

mb24 b_mult(
 .s(s),
 .d(d),
 .t(t),
 .q(q),
 .n(n),
 .my(Y),
 .tmy(TMY),
 .CLK(CLK),
 .product(product)
);


reg     [2*WIDTH-1:0]  product_reg;
always @(posedge CLK or negedge RST)
//always @(*)
begin
        if (RST == 1'b0)
        begin
          MAC_OUT_BUF0 <= `MAC_W'b0;
                  MAC_OUT_BUF1 <= `MAC_W'b0;
                  TEMP_SHIFT <= 1'b0;//Same delay as in prodcut
                  SHIFTEN_OUT <= 1'b0;//Same delay as in MAC     
        end

        else
        begin
                  TEMP_SHIFT <= SHIFTEN;//Same delay as in prodcut
          SHIFTEN_OUT <= TEMP_SHIFT;//Same delay as in MAC       
              MAC_OUT_BUF0 <=TEMP_SHIFT?SHIFTV:{MAC_OUT_FB+product_reg};
              MAC_OUT_BUF1 <=~TEMP_SHIFT?SHIFTV:{MAC_OUT_FB+product_reg};
        end
end

assign MAC_OUT_FB=SHIFTEN_OUT?MAC_OUT_BUF1:MAC_OUT_BUF0;//FeedBack to CSA [15:0] -- 16bit
assign MAC_OUT=~TEMP_SHIFT?MAC_OUT_BUF1:MAC_OUT_BUF0;//PE Output [15:0] -- 16bit



always @(posedge CLK)
begin
        if (RST == 1'b0)
        begin
        product_reg <= `MAC_W'b0;

        end

        else
begin
          product_reg<=product;

end
end
endmodule


module mb24 #(parameter WIDTH = 4)(
//input [WIDTH-1:0] mx,
input [WIDTH-1:0] my,
input CLK,
input RST,

//input  [1:0] s, d, t, q, n,
input  [1:0] s, d, t, q, n,
input  [WIDTH+1:0] tmy,


output [(WIDTH*2)-1:0] product);

parameter group_cnt=(WIDTH>>2)+1;

wire [WIDTH+1:0] epp2d[0:group_cnt - 1];

wire [WIDTH+2:0] fpp0;
wire [WIDTH+2:0] fpp1;

genvar i, j;
generate
    for (j = 0; j < group_cnt; j = j + 1) begin: b_selector
          booth_sel bs(.y2(my[0]),.y1(1'b0),.y0(1'b0), .ty(tmy[0]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][0]));
                  booth_sel bs0(.y2(my[1]), .y1(my[0]),.y0(1'b0), .ty(tmy[1]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][1]));
                  booth_sel bs1(.y2(my[2]),.y1(my[1]),.y0(my[0]), .ty(tmy[2]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][2]));
                  booth_sel bs2(.y2(my[3]),.y1(my[2]),.y0(my[1]), .ty(tmy[3]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][3]));
          booth_sel bs3(.y2(1'b0),.y1(my[3]),.y0(my[2]), .ty(tmy[4]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][4]));
          booth_sel bs4(.y2(1'b0),.y1(1'b0),.y0(my[3]), .ty(tmy[5]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][5]));

                end
endgenerate

//Partial Products
assign fpp0 = {~n[0] , epp2d[0]};
assign fpp1 = {~n[1] , epp2d[1]};

wire [7:0]cv= {4'b1100, n[1], 2'b00, n[0]};

//******************** STAGE 1 of Wallace tree ********************//
wire has000;
wire hac000;
wire has001;
wire hac001;
wire has002;
wire hac002;

wire ahas000;
wire ahac000;
wire ahas001;
wire ahac001;
wire ahas002;
wire ahac002;


wire [3:0] fas0;
wire [3:0] fac0;

wire [7:0] st00;
wire [6:0] st01;

//wire [39:0] st06;
//wire [34:0] st07;

HALF_ADDER ha000(.a(cv[0]), .b(fpp0[0]) , .sum(has000), .cout(hac000));
HALF_ADDER ha001(.a(cv[1]), .b(fpp0[1]) , .sum(has001), .cout(hac001));
HALF_ADDER ha002(.a(cv[2]), .b(fpp0[2]) , .sum(has002), .cout(hac002));

//HALF_ADDER aha000(.a(cv[5]), .b(fpp1[2]) , .sum(ahas000), .cout(ahac000));
//HALF_ADDER aha001(.a(cv[6]), .b(fpp1[3]) , .sum(ahas001), .cout(ahac001));
HALF_ADDER aha002(.a(cv[7]), .b(fpp1[4]) , .sum(ahas002), .cout(ahac002));

generate
        for (i = 0; i < 4; i = i + 1) begin:    for_s0
                FULL_ADDER fa000(.a(cv[i + 3]), .b(fpp0[i + 3]), .cin(fpp1[i]), .sum(fas0[i]), .cout(fac0[i]));
        end
endgenerate

assign st00 = {ahas002, fas0, has002, has001, has000};
assign st01 = {fac0, hac002, hac001, hac000};
//assign st00 = {ahas002, ahas001, ahas000, fas0, has002, has001, has000};
//assign st01 = {ahac001, ahac000, fac0, hac002, hac001, hac000};

assign product = st00 + {st01, 1'b0};

endmodule

/******************** Booth Selector ********************/
//module booth_selector(y,ty,single,double,triple,quad,neg,p);
module booth_sel(y2, y1, y0, ty, single, double, triple, quad, neg, p);

input y2;

input y1;

input y0;

input ty;

input single;

input double;

input triple;

input quad;

input neg;

output p;

assign  p = (neg ^ ((y2 & single)|(ty & triple)| (y1 & double) | (y0 & quad)));

endmodule









