module r8_mb8(mx,my,CLK,RST,product_final);
`include "./const/parameters_r8mb8.v"
//IO Start
input wire [WIDTH-1:0] mx;
input wire [WIDTH-1:0] my;
input wire CLK;
input wire RST;
output reg [(WIDTH*2)-1:0] product_final;
//IO End


wire [(WIDTH*2)-1:0] product;

wire [group_cnt - 1:0] s;  //single
wire [group_cnt - 1:0] d;  //double 
wire [group_cnt - 1:0] t;  //triple 
wire [group_cnt - 1:0] q;  //quadruple 
wire [group_cnt - 1:0] n;  //neg
wire [group_cnt - 1:0] nze;
wire [group_cnt - 1:0] pze;
wire [group_cnt - 1:0] e;

wire [WIDTH+1:0] epp2d[0:group_cnt - 1]; //[9:0][0:2] -- 10bits width, 3 depth
wire [10:0] fpp0; //[10:0] -- 11bits
wire [10:0] fpp1; //[10:0] -- 11bits
wire [9:0] fpp2; //[8:0] -- 9 bits

wire [WIDTH+1:0] tmy;

  //######################//
 //    3 Y Calculation   //
//######################//

pre_process_TMY prep00(.my(my),.CLK(CLK),.RST(RST), .TMY(tmy)); 

  //######################//
 //    Booth Encoding    //
//######################//

	booth3_encoder b_e0(.x({mx[2], mx[1], mx[0], 1'b0}), .single(s[0]), .double(d[0]), .triple(t[0]), .quad(q[0]), .neg(n[0]), .pzero(pze[0]), .nzero(nze[0]));
	booth3_encoder b_e1(.x({mx[5],mx[4], mx[3], mx[2]}), .single(s[1]), .double(d[1]), .triple(t[1]), .quad(q[1]), .neg(n[1]), .pzero(pze[1]), .nzero(nze[1]));
	booth3_encoder b_e2(.x({mx[WIDTH-1], mx[WIDTH - 1:WIDTH-3]}), .single(s[2]), .double(d[2]), .triple(t[2]), .quad(q[2]), .neg(n[2]), .pzero(pze[2]), .nzero(nze[2]));
	

  //######################//
 // 	 Selection       //
//######################//	

// Partial Products generation
genvar i, j;
generate//10 -- PartialProducts
    for (j = 0; j < group_cnt; j = j + 1) begin: b_selector 
       		m_booth_sel bs(.y({my[0],2'b00}), .ty(tmy[0]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][0]));
		m_booth_sel bs0(.y({my[1:0],1'b0}), .ty(tmy[1]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][1]));
		m_booth_sel bs1(.y(my[2:0]), .ty(tmy[2]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][2]));
		m_booth_sel bs2(.y(my[3:1]), .ty(tmy[3]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][3]));
		m_booth_sel bs3(.y(my[4:2]), .ty(tmy[4]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][4]));
		m_booth_sel bs4(.y(my[5:3]), .ty(tmy[5]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][5]));
		m_booth_sel bs5(.y(my[6:4]), .ty(tmy[6]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][6]));
		m_booth_sel bs6(.y(my[7:5]), .ty(tmy[7]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][7]));
		m_booth_sel bs7(.y({my[7], my[7:6]}), .ty(tmy[8]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][8]));  
		m_booth_sel bs8(.y({3{my[7]}}), .ty(tmy[9]), .single(s[j]), .double(d[j]), .triple(t[j]), .quad(q[j]), .neg(n[j]), .p(epp2d[j][9]));
end
endgenerate    



  //######################//
 // 	Signed Logic     //
//######################//

//extend signals
assign e[0] = nze[0] ? 1'b0:(~(my[WIDTH-1] ^ n[0]) | pze[0]);
assign e[1] = nze[1] ? 1'b0:(~(my[WIDTH-1] ^ n[1]) | pze[1]);
assign e[2] = nze[2] ? 1'b0:(~(my[WIDTH-1] ^ n[2]) | pze[2]);

//Partial Products
assign fpp0 = {~e[0] , epp2d[0]};       //[10:0] -- 11bits 
assign fpp1 = {e[1] , epp2d[1]};        //[10:0] -- 11bits
assign fpp2 = {e[2] , epp2d [2] [8:0]}; //[8:0] -- 9bits

//Correction vector
//wire [15:0]cv= {6'b110111,6'b000000,n[1],1'b0,1'b0,n[0]};

  //######################//
 // 	Reduction Tree   //
//######################//

wire [15:0] SUM; //[15:0] -- 16bits
wire [14:0] CARRY; //[14:0] -- 15bits
wire INT_SUM[14:0];
wire INT_CARRY[12:0];


/////////////////////1st STAGE /////////////////////////

HALF_ADDER HA0(.a(fpp0[0]), .b(n[0]) , .sum(INT_SUM[0]), .cout(INT_CARRY[0]));//HA0

assign SUM[0]=INT_SUM[0];
assign CARRY[0]=INT_CARRY[0];

assign INT_SUM[1]=fpp0[1];
assign SUM[1]=INT_SUM[1];
assign CARRY[1]=1'b0;

assign INT_SUM[2]=fpp0[2];
assign SUM[2]=INT_SUM[2];
assign CARRY[2]=1'b0;

FULL_ADDER FA0(.a(fpp0[3]), .b(fpp1[0]), .cin(n[1]), .sum(INT_SUM[3]), .cout(INT_CARRY[1]));//FA0
assign SUM[3]=INT_SUM[3];
assign CARRY[3]=INT_CARRY[1];

HALF_ADDER HA1(.a(fpp0[4]), .b(fpp1[1]) , .sum(INT_SUM[4]), .cout(INT_CARRY[2]));//HA1
assign SUM[4]=INT_SUM[4];
assign CARRY[4]=INT_CARRY[2];

HALF_ADDER HA2(.a(fpp0[5]), .b(fpp1[2]) , .sum(INT_SUM[5]), .cout(INT_CARRY[3]));//HA2
assign SUM[5]=INT_SUM[5];
assign CARRY[5]=INT_CARRY[3];

wire [7:0] mSUM;//
wire [7:0] mCARRY;

FULL_ADDER compress[7:0]({e[0],~e[0],~e[0],fpp0[10:6]}, fpp1[10:3],fpp2[7:0], mSUM, mCARRY);


/////////////////////2nd Stage /////////////////////////

HALF_ADDER HA3(.a(mSUM[0]), .b(n[2]) , .sum(INT_SUM[6]), .cout(INT_CARRY[4]));//HA3
assign SUM[6]=INT_SUM[6];
assign CARRY[6]=INT_CARRY[4];

HALF_ADDER HA4(.a(mSUM[1]), .b(mCARRY[0]) , .sum(INT_SUM[7]), .cout(INT_CARRY[5]));//HA4
assign SUM[7]=INT_SUM[7];
assign CARRY[7]=INT_CARRY[5];

HALF_ADDER HA5(.a(mSUM[2]), .b(mCARRY[1]) , .sum(INT_SUM[8]), .cout(INT_CARRY[6]));//HA5
assign SUM[8]=INT_SUM[8];
assign CARRY[8]=INT_CARRY[6];

HALF_ADDER HA6(.a(mSUM[3]), .b(mCARRY[2]) , .sum(INT_SUM[9]), .cout(INT_CARRY[7]));//HA6
assign SUM[9]=INT_SUM[9];
assign CARRY[9]=INT_CARRY[7];

HALF_ADDER HA7(.a(mSUM[4]), .b(mCARRY[3]) , .sum(INT_SUM[10]), .cout(INT_CARRY[8]));//HA7
assign SUM[10]=INT_SUM[10];
assign CARRY[10]=INT_CARRY[8];

HALF_ADDER HA8(.a(mSUM[5]), .b(mCARRY[4]) , .sum(INT_SUM[11]), .cout(INT_CARRY[9]));//HA8
assign SUM[11]=INT_SUM[11];
assign CARRY[11]=INT_CARRY[9];

HALF_ADDER HA9(.a(mSUM[6]), .b(mCARRY[5]) , .sum(INT_SUM[12]), .cout(INT_CARRY[10]));//HA9
assign SUM[12]=INT_SUM[12];
assign CARRY[12]=INT_CARRY[10];

HALF_ADDER HA10(.a(mSUM[7]), .b(mCARRY[6]) , .sum(INT_SUM[13]), .cout(INT_CARRY[11]));//HA10
assign SUM[13]=INT_SUM[13];
assign CARRY[13]=INT_CARRY[11];


FULL_ADDER FA1(.a(1'b1), .b(fpp2[8]), .cin(mCARRY[7]), .sum(INT_SUM[14]), .cout(INT_CARRY[12]));
assign SUM[14]=INT_SUM[14];
assign CARRY[14]=INT_CARRY[12];
assign SUM[15]=fpp2[9];

  //######################//
 // 	     CPA         //
//######################//

//wire last_carry;
assign product = SUM+{CARRY,1'b0};
//CLA_16 cla_product( .OPA(SUM), .OPB({CARRY,1'b0}), .CIN(1'b0), .PHI(1'b0), .SUM(product), .COUT(last_carry) );

always @(posedge CLK)
	product_final <= product;


endmodule


////////////////////////////////////////////////////////////////////////////////

/******************** Booth Encoder ********************/
module booth3_encoder (x, single, double, triple, quad, neg, pzero, nzero);

input [3:0]x;

output single;

output  double;

output triple;

output  quad;

output neg;

output pzero;

output nzero;

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

assign pzero = ~x[0] & ~x[1] & ~x[2] & ~x[3] ;//+0 Logic

assign nzero = x[0] & x[1] & x[2]& x[3]; //-0 Logic

endmodule


/******************** Booth Selector ********************/
module m_booth_sel(y, ty, single, double, triple, quad, neg, p);

input [2:0] y;

input ty;

input single;

input double;

input triple;

input quad;

input neg;

output p;

assign  p = (neg ^ ((y[2] & single)|(ty & triple)| (y[1] & double) | (y[0] & quad)));

endmodule

/******************** 1bit Full Adder ********************/
/*
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
*/
/***************************3Y Computation***************************/
module pre_process_TMY(my, CLK, RST, TMY);
`include "./const/parameters_r8mb8.v"
input signed [WIDTH-1:0] my;
input CLK;
input RST;
//output wire signed [WIDTH-1:0] my_out;
output wire [WIDTH+1:0] TMY;

wire [WIDTH+1:0] SUM;


assign SUM = my+(my<<1);
//CLA_9 cla_tmy( .OPA({my[WIDTH-1],my}), .OPB({my,1'b0}), .CIN(1'b0), .PHI(1'b0), .SUM(SUM[WIDTH:0]), .COUT(SUM[WIDTH+1]) );




assign TMY = SUM;
//assign my_out = my;

endmodule

/***************************3Y End***************************/










