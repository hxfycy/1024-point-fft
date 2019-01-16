	module but64
(
input [63:0] Y0,Y1,Y2,Y3,
input [2:0] state,          //calculation state 
input [63:0] TF1,TF2,TF3, //rotation factor
input clk,                  //posedge clk to latch output data after 1 period, 
input nrst,                   //negedge rst to clr
output reg[63:0]  X0,X1,X2,X3 ,
input  enable,
output reg fft_available
//test
// output wire signed[10:0] O1R,O2R,O3R,O1I,O2I,O3I,
// output wire signed[11:0] U0R,U1R,U0I,U1I,
// output wire signed[11:0] V0R,V1R,V0I,V1I,
// output wire signed[12:0] Z0R,Z1R,Z2R,Z3R,Z0I,Z1I,Z2I,Z3I,
// output reg [7:0]cnto;

);
reg enabled1;reg enabled2;reg enabled3;
wire [63:0] O1,O2,O3;        //mult output 
reg  [63:0] Y0d1,Y0d2,Y0d3;
/*
wire [23:0] U0,U1; //12bit 
wire [23:0] V0,V1; //
wire [25:0] Z0,Z1,Z2,Z3; //extend one bit to avoid overflow
*/
 booth64_cpx _m1(Y1,TF1,O1,clk);
     booth64_cpx _m2(Y2,TF2,O2,clk);
      booth64_cpx _m3(Y3,TF3,O3,clk);
  
wire signed[31:0]Y0R,Y0I,Y1R,Y1I,Y2R,Y2I,Y3R,Y3I;
assign Y0R=Y0d3[63:32];assign Y0I=Y0d3[31:0];assign Y1R=Y1[63:32];assign Y1I=Y1[31:0];
assign Y2R=Y2[63:32];assign Y2I=Y2[31:0];assign Y3R=Y3[63:32];assign Y3I=Y3[31:0];

wire signed[31:0] O1R,O2R,O3R,O1I,O2I,O3I;    //b30.8*b32.0   output>>8  cut off first 32 bits, no overflow will happen
wire signed[23:0] O1RR,O2RR,O3RR,O1II,O2II,O3II;
assign O1RR=O1[63:40];assign O1II=O1[31:8];assign O2RR=O2[63:40];assign O2II=O2[31:8];assign O3RR=O3[63:40];assign O3II=O3[31:8];
assign O1R=O1RR;assign O1I=O1II;assign O2R=O2RR;assign O2I=O2II;assign O3R=O3RR;assign O3I=O3II;
wire signed[31:0] U0R,U1R,U0I,U1I;
assign U0R=Y0R+O2R;//U0=Y0+O2
assign U0I=Y0I+O2I;
assign U1R=Y0R-O2R;//U1=Y0-O2
assign U1I=Y0I-O2I;

wire signed[31:0] V0R,V1R,V0I,V1I;
assign V0R=O1R+O3R;//V0=O1+O3
assign V0I=O1I+O3I;
assign V1R=O1R-O3R;//V1=O1-O3
assign V1I=O1I-O3I;

wire signed[31:0] Z0R,Z1R,Z2R,Z3R,Z0I,Z1I,Z2I,Z3I;
assign Z0R=U0R+V0R;assign Z0I=U0I+V0I;//Z0=U0+V0
assign Z1R=U1R+V1I;assign Z1I=U1I-V1R;//Z1=U1-jV1
assign Z2R=U0R-V0R;assign Z2I=U0I-V0I;//Z2=U0-V0
assign Z3R=U1R-V1I;assign Z3I=U1I+V1R;//Z3=U1+jV1

always@(posedge clk or negedge nrst)begin
 if(!nrst)
  begin
  X0<=64'b0;X1<=64'b0;X2<=64'b0;X3<=64'b0;
  fft_available<=1'b0;
  enabled1<=1'b0;
  enabled2<=1'b0;
  enabled3<=1'b0;
  Y0d1<=64'b0;
  Y0d2<=64'b0;
  Y0d3<=64'b0;
  end
 else if(enable||enabled1||enabled2||enabled3)begin
  Y0d1<=Y0;
  Y0d2<=Y0d1;
  Y0d3<=Y0d2;
  X0<={Z0R,Z0I};
  X1<={Z1R,Z1I};
  X2<={Z2R,Z2I};
  X3<={Z3R,Z3I};
  enabled1<=enable;
  enabled2<=enabled1;
  enabled3<=enabled2;
  fft_available<=enabled3;
  end
     else begin
   enabled1<=enable;
      enabled2<=enabled1;
	  enabled3<=enabled2;
      fft_available<=enabled3;
        X0<=64'b0;
  X1<=64'b0;
  X2<=64'b0;
  X3<=64'b0;
 end
end

endmodule 

module booth64_cpx(
input signed [63:0]mult1,mult2,//a+bi;c+di;
output reg signed [63:0]result,//ac-bd+(ad+bc)i=(A-B)+(B-C)i  no overflow wil happen
input clk
);  
wire signed [31:0]a,b,c,d;
assign a=mult1[63:32];
assign b=mult1[31:0];
assign c=mult2[63:32];
assign d=mult2[31:0];

wire signed [31:0]tmp_A,tmp_B,tmp_C;     //A=a+b, B=c+d, C=b-a
wire signed [31:0]prod_A,prod_B,prod_C;//A=(a+b)c;B=(c+d)b;C=(b-a)d
wire signed [31:0]result_high,result_low;
assign tmp_A=a+b;
assign tmp_B=c+d;
assign tmp_C=b-a;

booth64 _A(tmp_A,c,clk,prod_A);
booth64 _B(tmp_B,b,clk,prod_B);
booth64 _C(tmp_C,d,clk,prod_C);

assign result_high=prod_A-prod_B;
assign result_low=prod_B-prod_C;
//assign result={result_high,result_low};
always@(*)
begin
result<={result_high,result_low};
end
endmodule 
module booth64(
input signed  [31:0] mult1,mult2,
input clk,
output reg signed [31:0] part_prod
);
//reg signed [31:0] part_prod;
//assign result=part_prod;
reg signed[31:0] part_prodA,part_prodB,part_prodC,part_prodD,part_prodE,part_prodF,part_prodG,part_prodH;
reg signed[31:0] part_prod1,part_prod2;

reg signed[32:0] part_A1,part_A2,part_A3,part_A4,part_A5,part_A6,part_A7,part_A8; 
reg signed[32:0] part_A9,part_AA,part_AB,part_AC,part_AD,part_AE,part_AF,part_A0; 

wire signed a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,aa,ab,ac,ad,ae,af;


assign a0=part_A1[32];
assign a1=part_A2[32];
assign a2=part_A3[32];
assign a3=part_A4[32];
assign a4=part_A5[32];
assign a5=part_A6[32];
assign a6=part_A7[32];
assign a7=part_A8[32];
assign a8=part_A9[32];
assign a9=part_AA[32];
assign aa=part_AB[32];
assign ab=part_AC[32];
assign ac=part_AD[32];
assign ad=part_AE[32];
assign ae=part_AF[32];
assign af=part_A0[32];


always@(posedge clk)
begin       //1 2 3  4  5  6  7  8  9  10 11 12 13 14 15 16
part_prodA<=part_A1[31:0]+
          {part_A2[29:0],2'sb0};
		  
part_prodE<={part_A3[27:0],4'sb0}+
          {part_A4[25:0],6'sb0};
          
part_prodB<={part_A5[23:0],8'sb0}+
          {part_A6[21:0],10'sb0};
part_prodF<={part_A7[19:0],12'sb0}+
          {part_A8[17:0],14'sb0};

part_prodC<={part_A9[15:0],16'sb0}+
          {part_AA[13:0],18'sb0};
part_prodG<={part_AB[11:0],20'sb0}+
          {part_AC[9:0],22'sb0};

part_prodD<={part_AD[7:0],24'sb0}+
          {part_AE[5:0],26'sb0};
part_prodH<={part_AF[3:0],28'sb0}+
          {part_A0[1:0],30'sb0};

part_prod1<=part_prodA+part_prodB+part_prodC+part_prodD;
part_prod2<=part_prodE+part_prodF+part_prodG+part_prodH;

part_prod<=part_prod1+part_prod2;
end

always@(*)
begin
case(mult1[1:0])
  2'b00:part_A1=33'b0;
  2'b01:part_A1={mult2[31],mult2};
  2'b10:part_A1=-{mult2,1'b0};
  2'b11:part_A1=-{mult2[31],mult2};
  default:part_A1=33'b0;
endcase

case(mult1[3:1])
  3'b000:part_A2= 33'b0;
  3'b001:part_A2= {mult2[31],mult2};
  3'b010:part_A2= {mult2[31],mult2};
  3'b011:part_A2= {mult2,1'b0};
  3'b100:part_A2=-{mult2,1'b0};
  3'b101:part_A2=-{mult2[31],mult2};
  3'b110:part_A2=-{mult2[31],mult2};
  3'b111:part_A2= 33'b0;
default:part_A2= 33'b0;
endcase


case(mult1[5:3])
  3'b000:part_A3= 33'b0;
  3'b001:part_A3= {mult2[31],mult2};
  3'b010:part_A3= {mult2[31],mult2};
  3'b011:part_A3= {mult2,1'b0};
  3'b100:part_A3=-{mult2,1'b0};
  3'b101:part_A3=-{mult2[31],mult2};
  3'b110:part_A3=-{mult2[31],mult2};
  3'b111:part_A3= 33'b0;
default:part_A3= 33'b0;
endcase

case(mult1[7:5])
  3'b000:part_A4= 33'b0;
  3'b001:part_A4= {mult2[31],mult2};
  3'b010:part_A4= {mult2[31],mult2};
  3'b011:part_A4= {mult2,1'b0};
  3'b100:part_A4=-{mult2,1'b0};
  3'b101:part_A4=-{mult2[31],mult2};
  3'b110:part_A4=-{mult2[31],mult2};
  3'b111:part_A4= 33'b0;
default:part_A4= 33'b0;
endcase

case(mult1[9:7])
  3'b000:part_A5= 33'b0;
  3'b001:part_A5= {mult2[31],mult2};
  3'b010:part_A5= {mult2[31],mult2};
  3'b011:part_A5= {mult2,1'b0};
  3'b100:part_A5=-{mult2,1'b0};
  3'b101:part_A5=-{mult2[31],mult2};
  3'b110:part_A5=-{mult2[31],mult2};
  3'b111:part_A5= 33'b0;
default:part_A5= 33'b0;
endcase


case(mult1[11:9])
  3'b000:part_A6= 33'b0;
  3'b001:part_A6= {mult2[31],mult2};
  3'b010:part_A6= {mult2[31],mult2};
  3'b011:part_A6= {mult2,1'b0};
  3'b100:part_A6=-{mult2,1'b0};
  3'b101:part_A6=-{mult2[31],mult2};
  3'b110:part_A6=-{mult2[31],mult2};
  3'b111:part_A6= 33'b0;
default:part_A6= 33'b0;
endcase

case(mult1[13:11])
  3'b000:part_A7= 33'b0;
  3'b001:part_A7= {mult2[31],mult2};
  3'b010:part_A7= {mult2[31],mult2};
  3'b011:part_A7= {mult2,1'b0};
  3'b100:part_A7=-{mult2,1'b0};
  3'b101:part_A7=-{mult2[31],mult2};
  3'b110:part_A7=-{mult2[31],mult2};
  3'b111:part_A7= 33'b0;
default:part_A7= 33'b0;
endcase

case(mult1[15:13])
  3'b000:part_A8= 33'b0;
  3'b001:part_A8= {mult2[31],mult2};
  3'b010:part_A8= {mult2[31],mult2};
  3'b011:part_A8= {mult2,1'b0};
  3'b100:part_A8=-{mult2,1'b0};
  3'b101:part_A8=-{mult2[31],mult2};
  3'b110:part_A8=-{mult2[31],mult2};
  3'b111:part_A8= 33'b0;
default:part_A8= 33'b0;
endcase

case(mult1[17:15])
  3'b000:part_A9= 33'b0;
  3'b001:part_A9= {mult2[31],mult2};
  3'b010:part_A9= {mult2[31],mult2};
  3'b011:part_A9= {mult2,1'b0};
  3'b100:part_A9=-{mult2,1'b0};
  3'b101:part_A9=-{mult2[31],mult2};
  3'b110:part_A9=-{mult2[31],mult2};
  3'b111:part_A9= 33'b0;
default:part_A9= 33'b0;
endcase

case(mult1[19:17])
  3'b000:part_AA= 33'b0;
  3'b001:part_AA= {mult2[31],mult2};
  3'b010:part_AA= {mult2[31],mult2};
  3'b011:part_AA= {mult2,1'b0};
  3'b100:part_AA=-{mult2,1'b0};
  3'b101:part_AA=-{mult2[31],mult2};
  3'b110:part_AA=-{mult2[31],mult2};
  3'b111:part_AA= 33'b0;
default:part_AA= 33'b0;
endcase
case(mult1[21:19])
  3'b000:part_AB= 33'b0;
  3'b001:part_AB= {mult2[31],mult2};
  3'b010:part_AB= {mult2[31],mult2};
  3'b011:part_AB= {mult2,1'b0};
  3'b100:part_AB=-{mult2,1'b0};
  3'b101:part_AB=-{mult2[31],mult2};
  3'b110:part_AB=-{mult2[31],mult2};
  3'b111:part_AB= 33'b0;
default:part_AB= 33'b0;
endcase

case(mult1[23:21])
  3'b000:part_AC= 33'b0;
  3'b001:part_AC= {mult2[31],mult2};
  3'b010:part_AC= {mult2[31],mult2};
  3'b011:part_AC= {mult2,1'b0};
  3'b100:part_AC=-{mult2,1'b0};
  3'b101:part_AC=-{mult2[31],mult2};
  3'b110:part_AC=-{mult2[31],mult2};
  3'b111:part_AC= 33'b0;
default:part_AC= 33'b0;
endcase

case(mult1[25:23])
  3'b000:part_AD= 33'b0;
  3'b001:part_AD= {mult2[31],mult2};
  3'b010:part_AD= {mult2[31],mult2};
  3'b011:part_AD= {mult2,1'b0};
  3'b100:part_AD=-{mult2,1'b0};
  3'b101:part_AD=-{mult2[31],mult2};
  3'b110:part_AD=-{mult2[31],mult2};
  3'b111:part_AD= 33'b0;
default:part_AD= 33'b0;
endcase

case(mult1[27:25])
  3'b000:part_AE= 33'b0;
  3'b001:part_AE= {mult2[31],mult2};
  3'b010:part_AE= {mult2[31],mult2};
  3'b011:part_AE= {mult2,1'b0};
  3'b100:part_AE=-{mult2,1'b0};
  3'b101:part_AE=-{mult2[31],mult2};
  3'b110:part_AE=-{mult2[31],mult2};
  3'b111:part_AE= 33'b0;
default:part_AE= 33'b0;
endcase

case(mult1[29:27])
  3'b000:part_AF= 33'b0;
  3'b001:part_AF= {mult2[31],mult2};
  3'b010:part_AF= {mult2[31],mult2};
  3'b011:part_AF= {mult2,1'b0};
  3'b100:part_AF=-{mult2,1'b0};
  3'b101:part_AF=-{mult2[31],mult2};
  3'b110:part_AF=-{mult2[31],mult2};
  3'b111:part_AF= 33'b0;
default:part_AF= 33'b0;
endcase


case(mult1[31:29])
  3'b000:part_A0= 33'b0;
3'b001:part_A0= {mult2[31],mult2};
3'b010:part_A0= {mult2[31],mult2};
3'b011:part_A0= {mult2,1'b0};
3'b100:part_A0=-{mult2,1'b0};
3'b101:part_A0=-{mult2[31],mult2};
3'b110:part_A0=-{mult2[31],mult2};
3'b111:part_A0= 33'b0;
default:part_A0= 33'b0;
endcase
end


endmodule 