module top
    (
    input clk,
    input rxd,
    (*mark_debug="true"*)input sdi,
    output txd,
    (*mark_debug="true"*)output din,sck,cs, 
    //test
    //input nrst,
    (*mark_debug="true"*)input start_key
   // output reg fft_busy
    );
    
    //whole module rst
   // reg nrst;
   reg fft_busy;
   wire start_en;
   wire start_sync;
   wire nrst;
   wire rsten;
   assign nrst=!rsten;
  Falling2En#(
     16
   )_en(
     clk,start_key,
     start_en, start_sync
   );
   Rising2En#(
    16
   )
   _rst(
    clk,start_key,
    rsten,
   );
    initial fft_busy=1'b0;

    //uart receive
    wire [63:0]dout;
    wire dout_valid,busy;
    //reg  start;
    
    //uart send
    wire [63:0]uart_din;
    reg uart_start;
    wire send_busy;
    
    //fft_out
    wire [9:0]out_cnt;
    wire      out_avail;
    wire [31:0]out_RE;
    wire [31:0]out_IM;


    
    UartRx _rx(
       clk,nrst,rxd,
       dout,
       dout_valid, ,busy
    );
   
    fft_top _top
        (   
        din,sck,cs,
        sdi,
        clk,
        nrst,
         ,
        start_en&(!fft_busy),
        out_cnt,
        out_avail,
        out_RE,
        out_IM
        );
        wire ubuf_we;
        reg [9:0]ubuf_addr;
        wire [63:0]ubuf_data;
        reg usend_en;
        reg [9:0]usend_addr;
        wire [63:0]usend_data;
        reg send_ready;
        wire cnt_co,cnt0_co,cnt1_co;
        wire [9:0] uart_cnt;
        counterM
        # ( 1024)
        cnt2(
            clk,!nrst,
            uart_cnt,
            cnt0_co,
            cnt1_co   //co-->new enable   en-->old enable   
        );
        counterM
        # ( 67)
        cnt1(
            clk,!nrst,
             ,
            cnt_co,
            cnt0_co   //co-->new enable   en-->old enable   
        );
        counterM
                # (10)
                cnt(
                    clk,!nrst,
                     ,
                    send_ready,
                    cnt_co   //co-->new enable   en-->old enable   
                );
        always@(posedge clk)
        begin
            if(start_en)
             fft_busy<=1'b1;
            else if(cnt1_co) //send finished
             fft_busy<=1'b0;
        end

        initial send_ready=1'b0;
        assign ubuf_we=out_avail;
        assign ubuf_data={out_RE,out_IM};
        //assign usend_addr=uart_cnt;
        always@(posedge clk)
        begin
            usend_addr<=uart_cnt;
        end
        always@(posedge clk)
        begin
        ubuf_addr<=out_cnt;
            if(ubuf_addr==10'd1023)
            begin
                send_ready<=1'b1;
            end
            if(cnt1_co)
            begin
                send_ready<=1'b0;
            end
        end
                
        uart_buffer _uart
        (
        clk,
        ubuf_we,
        ubuf_addr,
        ubuf_data,
        clk,
        1'b1,
        usend_addr,
        usend_data
        );
        
        always@(posedge clk)
        begin
            uart_start<=cnt0_co;
        end
        assign uart_din=usend_data;
         UartTx _tx
        (
        clk,nrst,
        uart_din,
        uart_start,
        send_busy,txd
        );
endmodule 

module fft_top
    (   
    output wire din,sck,cs,
    input wire sdi,
    input clk,
    input nrst,
    input enable,//always enable
    //input data_ok,
    input start,
    output [9:0]out_cnt,
    output wire out_avail,
    output wire [31:0] serialout_RE,
    output wire [31:0] serialout_IM
    );
    //reg start;
    reg data_ok;
    initial data_ok=0;
    reg[31:0]datain;
    initial datain=32'b1;
    /*
        always@(posedge clk)begin
            if(data_ok)
           begin
            if(datain<32'd256)
            datain<=datain+1'b1;
            else
            datain<=32'b1;
            end
        end
        */
   
    wire [63:0]data;
    wire [63:0]ram_indata;
    
fft     _f
(
clk,
nrst,
1'b1,//whole module enable signal
data_ok,//indicate data is ready to input     
data,
serialout_RE,
serialout_IM,
out_cnt,
out_avail//output data available
);
    //dram instantiation
    wire ram_inwe;
    wire [9:0]ram_inaddr;
    wire ram_inok;
    reg ram_outen;
    wire [9:0]ram_outaddr;
    wire [63:0]ram_outdata;
    reg [9:0]ram_outcnt;
    reg [9:0]ram_outcntd1;
    assign ram_outaddr=ram_outcnt;
    assign data=ram_outdata;
        initial ram_outcnt<=10'b0;
        initial ram_outcntd1<=10'b0;
        initial ram_outen<=1'b0;
    always@(posedge clk)
    begin
        ram_outcntd1<=ram_outcnt;
    end
        
    reg buffer_enable;
        initial buffer_enable=1'b0;
     always@(posedge clk)
           begin
           data_ok<=buffer_enable;
           end
    always@(posedge clk)
    begin
        if(ram_inok)
            begin
                buffer_enable<=1'b1;
                ram_outen<=1'b1;
            end
        else if(ram_outcnt==10'd1023)
        begin
            buffer_enable<=1'b0;
            ram_outen<=1'b0;
        end
    end
    
    always@(posedge clk)
    begin
        if(buffer_enable)
        begin
            if(ram_outcnt<10'd1023)
                begin
                    ram_outcnt<=ram_outcnt+1'b1;
                end
            else
                begin
                    ram_outcnt<=1'b0;
                end
        end
        else 
        begin
            ram_outcnt<=10'b0;
        end
    end
    sb8865 _8865
    (
    din,sck,cs,
    sdi,
    clk,
    ,
    ram_indata,
    start,
    ram_inwe,
    ram_inaddr,
    ram_inok
    //output reg signed [15:0]shiftr,
    //output integer i
    );
    
    adbuffer _buffer
        (
        clk,
        ram_inwe,
        ram_inaddr,
        ram_indata,
        clk,
        ram_outen,
        ram_outaddr, 
        ram_outdata 
        );

endmodule 