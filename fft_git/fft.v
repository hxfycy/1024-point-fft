    module fft
(
input clk,
input nrst,
input enable,//whole module enable signal
input data_ok,//indicate data is ready to input     
input [63:0] serialin,
output wire [31:0] serialout_RE,
output wire [31:0] serialout_IM,
output reg [9:0] out_cnt,
output out_avail//output data available
);



//input timing:     clk  __/^^^^\____/^^^^
//                data_ok__/^^^^^^^^^^^^^
//                data ____data0-----data1-----

//output timing:    clk  __/^^^^\____/^^^
//         out_avail     __/--------------------^^\______
//              out_data___data0-----data1-data3ff\-----not care-------
localparam IDLE=3'b0;
localparam CT0=3'b1;
localparam CT1=3'd2;
localparam CT2=3'd3;
localparam CT3=3'd4;
localparam CT4=3'd5;
localparam OUT=3'd6;

//output 
reg [63:0] serialout;
reg out_delayen;
reg out_available;
assign serialout_RE=serialout[63:32];
assign serialout_IM=serialout[31:0];
assign out_avail=out_available|out_delayen;

//flag and enable
reg input_ok;   //input data storage finished
reg out_ok;  //data is ready for output
reg out_do;        //ram busy in output
reg buten; //butterfly enable signal
reg [2:0] state;//fft state register


//buffer 
reg [63:0] buf_wdata0;     //buffer to ram data
reg [7:0]  buf_waddr0;    //buffer to ram address
reg [63:0] buf_0[2:0];    //block buffer
reg [1:0]  buf_cnt0;    //block buffer counter
reg        buf_full0;    //buffer full flag
reg           buf_we0;

reg [63:0] buf_wdata1;
reg [7:0]  buf_waddr1;
reg [63:0] buf_1[2:0];
reg [1:0]  buf_cnt1;
reg        buf_full1;
reg           buf_we1;

reg [63:0] buf_wdata2;
reg [7:0]  buf_waddr2;
reg [63:0] buf_2[2:0];
reg [1:0]  buf_cnt2;
reg        buf_full2;
reg           buf_we2;

reg [63:0] buf_wdata3;
reg [7:0]  buf_waddr3;
reg [63:0] buf_3[2:0];
reg [1:0]  buf_cnt3;
reg        buf_full3;
reg           buf_we3;

wire        buf_clear;
assign        buf_clear=(!buf_full0)&&(!buf_full1)&&(!buf_full2)&&(!buf_full3);

//ram behavior module
reg ram0en;            //block enable
reg ram0we;            //write enable
reg [7:0]  ram0_waddr; // block0 write address
reg [7:0]  ram0_raddr; // block0 read address
reg [63:0] ram0_wdata; // block write data
wire[63:0] ram0_rdata; // block read data
reg ram1en;
reg ram1we;    
reg [7:0]  ram1_waddr;
reg [7:0]  ram1_raddr;
reg [63:0] ram1_wdata;
wire[63:0] ram1_rdata; 
reg ram2en;
reg ram2we;    
reg [7:0]  ram2_waddr;
reg [7:0]  ram2_raddr;
reg [63:0] ram2_wdata;
wire[63:0] ram2_rdata;
reg ram3en;
reg ram3we;    
reg [7:0]  ram3_waddr;
reg [7:0]  ram3_raddr;
reg [63:0] ram3_wdata;
wire[63:0] ram3_rdata;

//rom instantiation 
reg romen;
reg [7:0]rom_addr;
wire [63:0]TF1,TF2,TF3;

//ram instantiation
reg ram00en,ram01en,ram02en,ram03en,ram10en,ram11en,ram12en,ram13en;
reg ram00we,ram01we,ram02we,ram03we,ram10we,ram11we,ram12we,ram13we;
reg [7:0]addr00,addr01,addr02,addr03,addr10,addr11,addr12,addr13;
reg [63:0]ram00_wdata,ram01_wdata,ram02_wdata,ram03_wdata,ram10_wdata,ram11_wdata,ram12_wdata,ram13_wdata;
wire [63:0]ram00_rdata,ram01_rdata,ram02_rdata,ram03_rdata,ram10_rdata,ram11_rdata,ram12_rdata,ram13_rdata;

//butterfly_instantiation
reg  [63:0]Y0,Y1,Y2,Y3;
wire [63:0] X0,X1,X2,X3;
wire fft_available;// indicate that FFT_OUT is available

//pointer and counter
reg [1:0]ram_index;//read ram choose
reg [7:0] cnt;   //fft_cnt
reg [7:0] cntd1; //fft_cnt delay 1 T
reg [7:0] cntd2; //fft_cnt delay 2 T
reg [7:0] cntd3; //fft_cnt delay 3 T for adder buffer
reg [7:0] cntd4; //fft_cnt deay  4 T for adder buffer
reg [7:0] cntd5; 
reg [9:0] outcnt;//output data counter  ,test only    
reg [9:0] outcntd1;//output counter delay 1 t
reg [9:0] outcntd2;//output counter delay 2 t
reg [9:0] incnt;//input data counter

//ram_waddr generation
always@(posedge clk or negedge nrst)begin
if(!nrst)
begin
ram_index<=2'b0;
ram0_waddr<=8'b0;ram1_waddr<=8'b0;ram2_waddr<=8'b0;ram3_waddr<=8'b0;
ram0we<=1'b0;ram1we<=1'b0;ram2we<=1'b0;ram3we<=1'b0;
incnt<=10'b0;
input_ok<=1'b0;
end
else begin 
case(state)
IDLE:
begin
if(data_ok&&!input_ok&&enable)
begin
incnt<=incnt+1;
ram0_waddr<=incnt[7:0];ram1_waddr<=incnt[7:0];ram2_waddr<=incnt[7:0];ram3_waddr<=incnt[7:0];
case(incnt[9:8])
2'b00:begin ram0we<=1'b1;ram1we<=1'b0;ram2we<=1'b0;ram3we<=1'b0;ram0_wdata<=serialin; end
2'b01:begin ram0we<=1'b0;ram1we<=1'b1;ram2we<=1'b0;ram3we<=1'b0;ram1_wdata<=serialin; end
2'b10:begin ram0we<=1'b0;ram1we<=1'b0;ram2we<=1'b1;ram3we<=1'b0;ram2_wdata<=serialin; end
2'b11:begin ram0we<=1'b0;ram1we<=1'b0;ram2we<=1'b0;ram3we<=1'b1;ram3_wdata<=serialin; end
default:begin ram0we<=1'b0;ram1we<=1'b0;ram2we<=1'b0;ram3we<=1'b0; end
endcase
if(incnt==10'd1023)
begin
input_ok<=1'b1;        //data_input is ok 
ram_index<=2'b0;
end
else input_ok<=1'b0;
end
end
CT0:
begin
ram0we<=fft_available;ram1we<=ram0we;ram2we<=ram1we;ram3we<=ram2we;    
ram0_waddr<={cntd2[1:0],cntd2[7:2]};ram1_waddr<=ram0_waddr;ram2_waddr<=ram1_waddr;
end
CT1,CT2,CT3:// same as CT0
begin
ram0we<=fft_available;ram1we<=ram0we;ram2we<=ram1we;ram3we<=ram2we;  
ram0_waddr<={cntd5[1:0],cntd5[7:2]};ram1_waddr<=ram0_waddr;ram2_waddr<=ram1_waddr;
end
endcase
end
end

//rom_addr generation
always@(*)
begin
if(!nrst)
begin
romen<=1'b0;
rom_addr<=8'b0;
end
else 
begin
case(state)
IDLE:
begin
romen=1'b0;
end

CT0:
begin
rom_addr=8'b0;
end

CT1:
begin
rom_addr={cnt[7:6],6'b0};
end

CT2:
begin
rom_addr={cnt[7:4],4'b0};
end

CT3:
begin
rom_addr={cnt[7:2],2'b0};
end

CT4:
begin
rom_addr=cnt;
end

default:
begin
romen<=1'b0;
rom_addr<=8'b0;
end
endcase 
end
end

//ram_raddr generation   
always@(posedge clk or negedge nrst)
begin
if(!nrst)
begin
out_cnt<=10'b0;
outcnt<=10'b0;
outcntd1<=10'b0;
outcntd2<=10'b0;
out_available<=1'b0;
out_delayen<=1'b0;
out_do<=1'b0;
ram0_raddr<=8'b0;ram1_raddr<=8'b0;ram2_raddr<=8'b0;ram3_raddr<=8'b0;
end
else 
case(state)
OUT:
begin
if(!out_do)
begin
if(out_ok==1)
begin
out_do<=1'b1;
ram0_raddr<=8'b0;ram1_raddr<=8'b0;ram2_raddr<=8'b0;ram3_raddr<=8'b0;
end
else 
begin
ram0_raddr<=8'b0;ram1_raddr<=8'b0;ram2_raddr<=8'b0;ram3_raddr<=8'b0;
ram0en<=1'b1;ram1en<=1'b1;ram2en<=1'b1;ram3en<=1'b1;
end
end
else if(out_do)
begin
outcnt<=outcnt+1'b1;
ram0_raddr<=outcnt[7:0];ram1_raddr<=outcnt[7:0];ram2_raddr<=outcnt[7:0];ram3_raddr<=outcnt[7:0];
case(outcnt[9:8])
2'b00:begin ram0en<=1'b1;ram1en<=1'b0;ram2en<=1'b0;ram3en<=1'b0; end
2'b01:begin ram0en<=1'b0;ram1en<=1'b1;ram2en<=1'b0;ram3en<=1'b0; end
2'b10:begin ram0en<=1'b0;ram1en<=1'b0;ram2en<=1'b1;ram3en<=1'b0; end
2'b11:begin ram0en<=1'b0;ram1en<=1'b0;ram2en<=1'b0;ram3en<=1'b1; end
default:begin ram0en<=1'b0;ram1en<=1'b0;ram2en<=1'b0;ram3en<=1'b0; end 
endcase
if(outcnt==10'd1023)
begin
outcnt<=10'b0;
out_do<=1'b0;
//ram0en<=1'b1;ram1en<=1'b1;ram2en<=1'b1;ram3en<=1'b1;
end
end
outcntd1<=outcnt;
outcntd2<=outcntd1;
out_delayen<=out_available;
out_cnt<=outcntd1;
if(outcntd1==10'b1)
begin out_available<=1'b1; end
else if(outcntd2==10'd1023)
begin out_available<=1'b0; end

case(outcntd2[9:8])
2'b00:begin serialout<=ram10_rdata; end
2'b01:begin serialout<=ram11_rdata; end
2'b10:begin serialout<=ram12_rdata; end
2'b11:begin serialout<=ram13_rdata; end
default:serialout<=64'b0;
endcase
end
endcase
end

//state transition
always@(posedge clk or negedge nrst)
begin
if(!nrst)
begin
state<=IDLE;
ram0en<=0;
ram1en<=0;
ram2en<=0;
ram3en<=0;
ram_index<=1'b0;
out_ok<=1'b0;
cnt<=0;
cntd1<=0;
cntd2<=0;
cntd3<=0;
cntd4<=0;
cntd5<=0;
end

else case(state)
IDLE: 
begin
if(enable&&input_ok&&(incnt==10'b0))
begin
cnt<=0;
ram_index=1'b0;
state<=CT0;
//buten<=1'b1;
end
else begin
cnt<=8'b0;
cntd1<=8'b0;
cntd2<=8'b0;
cntd3<=8'b0;
cntd4<=8'b0;
cntd5<=8'b0;
ram_index=1'b0;
buten<=1'b0;
//input_ok<=1'b0;
end
end
CT0:
begin
if(cnt==8'b0&&cntd5==8'b0)
begin
buten<=1'b1;
end
if(cntd1==8'd255)
begin
buten<=1'b0;
end
if(cntd5==8'd255)
begin
cnt<=8'd0;
cntd1<=8'd0;
cntd2<=8'd0;
cntd3<=8'd0;
cntd4<=8'b0;
if(buf_clear&&(!ram13we))
begin
state<=CT1;
cntd5<=8'd0;
end
end
else 
begin
cnt<=cnt+1'b1;
cntd1<=cnt;
cntd2<=cntd1;
cntd3<=cntd2;
cntd4<=cntd3;
cntd5<=cntd4;
end
end

CT1:   // same as CT0
begin
if(cnt==8'b0&&cntd5==8'b0)
begin
buten<=1'b1;
end
if(cntd1==8'd255)
begin
buten<=1'b0;
end
if(cntd5==8'd255)
begin
cnt<=8'd0;
cntd1<=8'd0;
cntd2<=8'd0;
cntd3<=8'd0;
cntd4<=8'd0;
if(buf_clear&&(!ram13we))
begin
state<=CT2;
cntd5<=8'd0;
end
end
else 
begin
cnt<=cnt+1'b1;
cntd1<=cnt;
cntd2<=cntd1;
cntd3<=cntd2;
cntd4<=cntd3;
cntd5<=cntd4;
end

end
CT2:   // same as CT0
begin
if(cnt==8'b0&&cntd5==8'b0)
begin
buten<=1'b1;
end
if(cntd1==8'd255)
begin
buten<=1'b0;
end
if(cntd5==8'd255)
begin
cnt<=8'd0;
cntd1<=8'd0;
cntd2<=8'd0;
cntd3<=8'd0;
cntd4<=8'd0;
if(buf_clear&&(!ram13we))
begin
state<=CT3;
cntd5<=8'd0;
end
end
else 
begin
cnt<=cnt+1'b1;
cntd1<=cnt;
cntd2<=cntd1;
cntd3<=cntd2;
cntd4<=cntd3;
cntd5<=cntd4;
end
end

CT3:   // same as CT0
begin
if(cnt==8'b0&&cntd5==8'b0)
begin
buten<=1'b1;
end
if(cntd1==8'd255)
begin
buten<=1'b0;
end
if(cntd5==8'd255)
begin
cnt<=8'd0;
cntd1<=8'd0;
cntd2<=8'b0;
cntd3<=8'b0;
cntd4<=8'b0;
if(buf_clear&&(!ram13we))
begin
state<=CT4;
cntd5<=8'd0;
end
end
else 
begin
cnt<=cnt+1'b1;
cntd1<=cnt;
cntd2<=cntd1;
cntd3<=cntd2;
cntd4<=cntd3;
cntd5<=cntd4;
end
end

CT4:   // same as CT0
begin

if(cnt==8'b0&&cntd5==8'b0)
begin
buten<=1'b1;
end
if(cntd1==8'd255)
begin
buten<=1'b0;
end
if(cntd5==8'd255)
begin
cnt<=8'd0;
cntd1<=8'd0;
cntd2<=8'b0;
cntd3<=8'b0;
cntd4<=8'b0;
if(buf_clear&&!fft_available)
begin
state<=OUT;
out_ok<=1'b1;
end
end
else 
begin
cnt<=cnt+1'b1;
cntd1<=cnt;
cntd2<=cntd1;
cntd3<=cntd2;
cntd4<=cntd3;
cntd5<=cntd4;
end

end

OUT:
begin
out_ok<=1'b0;
end
endcase
end  

//buffer behavioral model
always@(posedge clk or negedge nrst)
begin
if(!nrst)
begin
buf_wdata0<=64'b0;
buf_waddr0<=8'b0;
buf_0[0]<=64'b0;
buf_0[1]<=64'b0;
buf_0[2]<=64'b0;
buf_cnt0<=2'b0;
buf_full0<=1'b0;
buf_we0<=1'b0;

buf_wdata1<=64'b0;
buf_waddr1<=8'b0;
buf_1[0]<=64'b0;
buf_1[1]<=64'b0;
buf_1[2]<=64'b0;
buf_cnt1<=2'b0;
buf_full1<=1'b0;
buf_we1<=1'b0;

buf_wdata2<=64'b0;
buf_waddr2<=8'b0;
buf_2[0]<=64'b0;
buf_2[1]<=64'b0;
buf_2[2]<=64'b0;
buf_cnt2<=2'b0;
buf_full2<=1'b0;
buf_we2<=1'b0;

buf_wdata3<=64'b0;
buf_waddr3<=8'b0;
buf_3[0]<=64'b0;
buf_3[1]<=64'b0;
buf_3[2]<=64'b0;
buf_cnt3<=2'b0;
buf_full3<=1'b0;
buf_we3<=1'b0;

end

else 
begin 
if(buf_full0)//buff0
begin
case(state)
CT0:
begin
buf_wdata0<=buf_0[buf_cnt0];
buf_waddr0<={cntd5[1:0],cntd5[7:2]};
buf_we0<=1'b1;
if(buf_cnt0==2'd2)
begin
buf_cnt0<=2'b0;
buf_full0<=1'b0;
end

else buf_cnt0<=buf_cnt0+1'b1;
end
CT1,CT2,CT3://same as CT0, Don't use buffer in CT4
begin
buf_wdata0<=buf_0[buf_cnt0];
buf_waddr0<={cntd5[1:0],cntd5[7:2]};
buf_we0<=1'b1;
if(buf_cnt0==2'd2)
begin
buf_cnt0<=2'b0;
buf_full0<=1'b0;
end
else buf_cnt0<=buf_cnt0+1'b1;
end

default:
begin
buf_wdata0<=64'b0;
buf_waddr0<=8'b0;
buf_we0<=1'b0;
buf_cnt0<=2'b0;
buf_full0<=1'b0;
end
endcase
end
else 
begin
case(state)
CT0:if(cntd5[1:0]==2'b0&&fft_available)
begin
buf_wdata0<=X0;
buf_waddr0<={cntd5[1:0],cntd5[7:2]};
buf_we0<=1'b1;
buf_0[0]<=X1;
buf_0[1]<=X2;
buf_0[2]<=X3;
buf_full0<=1'b1;
end
CT1,CT2,CT3:if(cntd5[1:0]==2'b0&&fft_available)
begin
buf_wdata0<=X0;
buf_waddr0<={cntd5[1:0],cntd5[7:2]};
buf_we0<=1'b1;
buf_0[0]<=X1;
buf_0[1]<=X2;
buf_0[2]<=X3;
buf_full0<=1'b1;
end
default:
begin
buf_wdata0<=64'b0;
buf_waddr0<=8'b0;
buf_we0<=1'b0;
buf_0[0]<=64'b0;
buf_0[1]<=64'b0;
buf_0[2]<=64'b0;
buf_full0<=1'b0;
end
endcase
end    


if(buf_full1)//buff1
begin
case(state)
CT0:
begin
buf_wdata1<=buf_1[buf_cnt1];
buf_waddr1<=buf_waddr0;
buf_we1<=1'b1;
if(buf_cnt1==2'd2)
begin
buf_cnt1<=2'b0;
buf_full1<=1'b0;
end
else buf_cnt1<=buf_cnt1+1'b1;
end
CT1,CT2,CT3:
begin
buf_wdata1<=buf_1[buf_cnt1];
buf_waddr1<=buf_waddr0;
buf_we1<=1'b1;
if(buf_cnt1==2'd2)
begin
buf_cnt1<=2'b0;
buf_full1<=1'b0;
end
else buf_cnt1<=buf_cnt1+1'b1;
end
default:
begin
buf_wdata1<=64'b0;
buf_waddr1<=8'b0;
buf_we1<=1'b0;
buf_cnt1<=2'b0;
buf_full1<=1'b0;
end
endcase

end
else begin
case(state)
CT0:if(cntd5[1:0]==2'b1&&fft_available)
begin
buf_wdata1<=X0;
buf_waddr1<=buf_waddr0;
buf_we1<=1'b1;
buf_1[0]<=X1;
buf_1[1]<=X2;
buf_1[2]<=X3;
buf_full1<=1'b1;
end
CT1,CT2,CT3://
begin
if(cntd5[1:0]==2'b1&&fft_available)
begin
buf_wdata1<=X0;
buf_waddr1<=buf_waddr0;
buf_we1<=1'b1;
buf_1[0]<=X1;
buf_1[1]<=X2;
buf_1[2]<=X3;
buf_full1<=1'b1;
end
end
default:
begin
buf_wdata1<=64'b0;
buf_waddr1<=8'b0;
buf_we1<=1'b0;
buf_1[0]<=64'b0;
buf_1[1]<=64'b0;
buf_1[2]<=64'b0;
buf_full1<=1'b0;
end
endcase
end    

if(buf_full2)//buff2
begin
case(state)
CT0:
begin
buf_wdata2<=buf_2[buf_cnt2];
buf_waddr2<=buf_waddr1;
buf_we2<=1'b1;
if(buf_cnt2==2'd2)
begin
buf_cnt2<=2'b0;
buf_full2<=1'b0;
end
else buf_cnt2<=buf_cnt2+1'b1;
end
CT1,CT2,CT3:
begin
buf_wdata2<=buf_2[buf_cnt2];
buf_waddr2<=buf_waddr1;
buf_we2<=1'b1;
if(buf_cnt2==2'd2)
begin
buf_cnt2<=2'b0;
buf_full2<=1'b0;
end
else buf_cnt2<=buf_cnt2+1'b1;
end
default:
begin
        buf_wdata2<=64'b0;
        buf_waddr2<=8'b0;
        buf_we2<=1'b0;
        buf_cnt2<=2'b0;
        buf_full2<=1'b0;
end
endcase

end
else 
begin
case(state)
CT0:if(cntd5[1:0]==2'b10&&fft_available)
begin
buf_wdata2<=X0;
buf_waddr2<=buf_waddr1;
buf_we2<=1'b1;
buf_2[0]<=X1;
buf_2[1]<=X2;
buf_2[2]<=X3;
buf_full2<=1'b1;
end
CT1,CT2,CT3:if(cntd5[1:0]==2'b10&&fft_available)
begin
buf_wdata2<=X0;
buf_waddr2<=buf_waddr1;
buf_we2<=1'b1;
buf_2[0]<=X1;
buf_2[1]<=X2;
buf_2[2]<=X3;
buf_full2<=1'b1;
end
default:
begin
buf_wdata2<=64'b0;
buf_waddr2<=8'b0;
buf_we2<=1'b0;
buf_2[0]<=64'b0;
buf_2[1]<=64'b0;
buf_2[2]<=64'b0;
buf_full2<=1'b0;
end
endcase
end    

if(buf_full3)//buff3
begin
case(state)
CT0:
begin
buf_wdata3<=buf_3[buf_cnt3];
buf_waddr3<=buf_waddr2;
buf_we3<=1'b1;
if(buf_cnt3==2'd2)
begin
buf_cnt3<=2'b0;
buf_full3<=1'b0;
end
else buf_cnt3<=buf_cnt3+1'b1;
end
CT1,CT2,CT3:
begin
buf_wdata3<=buf_3[buf_cnt3];
buf_waddr3<=buf_waddr2;
buf_we3<=1'b1;
if(buf_cnt3==2'd2)
begin
buf_cnt3<=2'b0;
buf_full3<=1'b0;
end
else buf_cnt3<=buf_cnt3+1'b1;
end
default:
begin
buf_wdata3<=64'b0;
buf_waddr3<=64'b0;
buf_we3<=1'b0;
buf_cnt3<=2'b0;
buf_full3<=1'b0;
end
endcase

end
else 
begin
case(state)
CT0:if(cntd5[1:0]==2'd3&&fft_available)
begin
buf_wdata3<=X0;
buf_waddr3<=buf_waddr2;
buf_we3<=1'b1;
buf_3[0]<=X1;
buf_3[1]<=X2;
buf_3[2]<=X3;
buf_full3<=1'b1;
end
CT1,CT2,CT3:if(cntd5[1:0]==2'd3&&fft_available)
begin
buf_wdata3<=X0;
buf_waddr3<=buf_waddr2;
buf_we3<=1'b1;
buf_3[0]<=X1;
buf_3[1]<=X2;
buf_3[2]<=X3;
buf_full3<=1'b1;
end
default:
begin
buf_wdata3<=64'b0;
buf_waddr3<=64'b0;
buf_we3<=1'b0;
buf_3[0]<=64'b0;
buf_3[1]<=64'b0;
buf_3[2]<=64'b0;
buf_full3<=1'b0;
end
endcase
end    

end
end


//ram instantiation and MUX
always@(*)
begin
case(state)
IDLE:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b0;ram11en=1'b0;ram12en=1'b0;ram13en=1'b0;
ram00we=ram0we; ram01we=ram1we; ram02we=ram2we; ram03we=ram3we;ram10we=0;ram11we=0;ram12we=0;ram13we=0;
addr00=ram0_waddr; addr01=ram1_waddr; addr02=ram2_waddr; addr03=ram3_waddr;
ram00_wdata=ram0_wdata; ram01_wdata=ram1_wdata; ram02_wdata=ram2_wdata; ram03_wdata=ram3_wdata;
end

CT0:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
ram00we=1'b0;ram01we=1'b0;ram02we=1'b0;ram03we=1'b0;ram10we=ram0we;ram11we=ram1we;ram12we=ram2we;ram13we=ram3we;
addr00={cnt[1:0],cnt[7:2]};addr01={cnt[1:0],cnt[7:2]};addr02={cnt[1:0],cnt[7:2]};addr03={cnt[1:0],cnt[7:2]};addr10=buf_waddr0;addr11=buf_waddr1;addr12=buf_waddr2;addr13=buf_waddr3;
ram10_wdata=buf_wdata0;ram11_wdata=buf_wdata1;ram12_wdata=buf_wdata2;ram13_wdata=buf_wdata3;
end

CT1:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
ram00we=ram0we;ram01we=ram1we;ram02we=ram2we;ram03we=ram3we;ram10we=1'b0;ram11we=1'b0;ram12we=1'b0;ram13we=1'b0;
addr00=buf_waddr0;addr01=buf_waddr1;addr02=buf_waddr2;addr03=buf_waddr3;addr10={cnt[7:6],cnt[1:0],cnt[5:2]};addr11=addr10;addr12=addr11;addr13=addr12;
ram00_wdata=buf_wdata0;ram01_wdata=buf_wdata1;ram02_wdata=buf_wdata2;ram03_wdata=buf_wdata3;
end

CT2:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
ram00we=1'b0;ram01we=1'b0;ram02we=1'b0;ram03we=1'b0;ram10we=ram0we;ram11we=ram1we;ram12we=ram2we;ram13we=ram3we;
addr00={cnt[7:4],cnt[1:0],cnt[3:2]};addr01=addr00;addr02=addr00;addr03=addr00;addr10=buf_waddr0;addr11=buf_waddr1;addr12=buf_waddr2;addr13=buf_waddr3;
ram10_wdata=buf_wdata0;ram11_wdata=buf_wdata1;ram12_wdata=buf_wdata2;ram13_wdata=buf_wdata3;
end

CT3:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
ram00we=ram0we;ram01we=ram1we;ram02we=ram2we;ram03we=ram3we;ram10we=1'b0;ram11we=1'b0;ram12we=1'b0;ram13we=1'b0;
addr00=buf_waddr0;addr01=buf_waddr1;addr02=buf_waddr2;addr03=buf_waddr3;addr10=cnt;addr11=addr10;addr12=addr11;addr13=addr12;
ram00_wdata=buf_wdata0;ram01_wdata=buf_wdata1;ram02_wdata=buf_wdata2;ram03_wdata=buf_wdata3;
end
CT4:
begin
ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
ram00we=1'b0;ram01we=1'b0;ram02we=1'b0;ram03we=1'b0;ram10we=fft_available;ram11we=ram10we;ram12we=ram10we;ram13we=ram10we;
addr00=cnt;addr01=addr00;addr02=addr00;addr03=addr00;addr10=cntd5;addr11=addr10;addr12=addr10;addr13=addr10;
ram10_wdata=X0;ram11_wdata=X1;ram12_wdata=X2;ram13_wdata=X3;
end                

OUT:
begin
ram00en=1'b0;ram01en=1'b0;ram02en=1'b0;ram03en=1'b0;ram10en=1'b1;ram11en=1'b1;ram12en=1'b1;ram13en=1'b1;
//test
//ram00en=1'b1;ram01en=1'b1;ram02en=1'b1;ram03en=1'b1;ram10en=1'b0;ram11en=1'b0;ram12en=1'b0;ram13en=1'b0;
//testend
ram00we=0; ram01we=0; ram02we=0; ram03we=0;
ram10we=0; ram11we=0; ram12we=0; ram13we=0;

addr10=ram0_raddr; addr11=ram1_raddr; addr12=ram2_raddr; addr13=ram3_raddr; 

end
endcase 
end
bram_00 _ram00(.clka(clk),.ena(ram00en),.wea(ram00we),.addra(addr00), .dina(ram00_wdata), .douta(ram00_rdata));
bram_01 _ram01(.clka(clk),.ena(ram01en),.wea(ram01we),.addra(addr01), .dina(ram01_wdata), .douta(ram01_rdata));
bram_02 _ram02(.clka(clk),.ena(ram02en),.wea(ram02we),.addra(addr02), .dina(ram02_wdata), .douta(ram02_rdata));
bram_03 _ram03(.clka(clk),.ena(ram03en),.wea(ram03we),.addra(addr03), .dina(ram03_wdata), .douta(ram03_rdata));
bram_10 _ram10(.clka(clk),.ena(ram10en),.wea(ram10we),.addra(addr10), .dina(ram10_wdata), .douta(ram10_rdata));
bram_11 _ram11(.clka(clk),.ena(ram11en),.wea(ram11we),.addra(addr11), .dina(ram11_wdata), .douta(ram11_rdata));
bram_12 _ram12(.clka(clk),.ena(ram12en),.wea(ram12we),.addra(addr12), .dina(ram12_wdata), .douta(ram12_rdata));
bram_13 _ram13(.clka(clk),.ena(ram13en),.wea(ram13we),.addra(addr13), .dina(ram13_wdata), .douta(ram13_rdata));

//rom instantiation 

tf1 _tf1(clk,1'b1,rom_addr,TF1);
tf2 _tf2(clk,1'b1,rom_addr,TF2);
tf3 _tf3(clk,1'b1,rom_addr,TF3);  


//buterfly unit instantiation and MUX

always@(*)
begin
case(state)
IDLE:
begin

end
CT0,CT2,CT4:
begin
Y0=ram00_rdata;Y1=ram01_rdata;Y2=ram02_rdata;Y3=ram03_rdata;  
end
CT1,CT3:
begin
Y0=ram10_rdata;Y1=ram11_rdata;Y2=ram12_rdata;Y3=ram13_rdata;  
end

default:
begin
Y0=64'b0;Y1=64'b0;Y2=64'b0;Y3=64'b0;
end
endcase
end

but64 _but
(
Y0,Y1,Y2,Y3,
state,          //calculation state 
TF1,TF2,TF3, //rotation factor
clk,                  //posedge clk to latch output data after 1 period, 
nrst,                   //negedge rst to clr
X0,X1,X2,X3,
buten,
fft_available
//test
// output wire signed[10:0] O1R,O2R,O3R,O1I,O2I,O3I,
// output wire signed[11:0] U0R,U1R,U0I,U1I,
// output wire signed[11:0] V0R,V1R,V0I,V1I,
// output wire signed[12:0] Z0R,Z1R,Z2R,Z3R,Z0I,Z1I,Z2I,Z3I,
// output reg [7:0]cnto;

);
endmodule 