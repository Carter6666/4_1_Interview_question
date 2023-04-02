
module axi_stream_insert_header 
#(
  parameter   DATA_WD      = 32         ,
  parameter   DATA_BYTE_WD = DATA_WD/8,
  //输入data_in数据的拍数
  parameter   data_in_num  = 5
) 
(
  input                           clk      ,
  input                           rst_n    ,
  
  //输入的AXI_Stream数据流data_in相关接口
  input                           valid_in ,
  input   [DATA_WD-1 : 0]         data_in  ,
  input   [DATA_BYTE_WD-1 : 0]    keep_in  ,
  input                           last_in  ,
  output                          ready_in ,
  
  //输出插入帧之后的的AXI_Stream数据流
  output  reg                        valid_out,
  output  reg [DATA_WD-1 : 0]         data_out ,
  output  reg [DATA_BYTE_WD-1 : 0]    keep_out ,
  output  reg                        last_out ,
  input                           ready_out,
  
  //输入的插入帧数据相关接口
  input                           valid_insert ,
  input   [DATA_WD-1 : 0]         header_insert,
  input   [DATA_BYTE_WD-1 : 0]    keep_insert  ,
  output                          ready_insert
);

  assign  ready_in      =  valid_in    ;
  assign  ready_insert  =  valid_insert;
  
  //定义reg变量cnt0,对数据data_in中最后一个数据的keep_in中比特位为0的位数进行计数（如keep_in=4'b1000时，cnt0=3）
  reg     [DATA_BYTE_WD-1 : 0]    cnt0; 
  //定义reg变量cnt1,对数据keep_insert中比特位为1的位数进行计数（如keep_insert=4'b0011时，cnt1=2）  
  reg     [DATA_BYTE_WD-1 : 0]    cnt1;
  //打一拍
  reg                             last_in_r;
  reg                             valid_insert_r;
  reg     [DATA_WD-1 : 0]         header_insert_r;
  reg     [DATA_WD-1 : 0]         data_in_r1;
  //打两拍
  reg     [DATA_WD-1 : 0]         data_in_r2;
  //data_in_r1、data_in_r1拼接标志信号
  reg                             flag_patch;
  //输出AXI_Stream多拍数据个数为data_in_num+1的标志位，若该信号有拉高，表明输出数据流个数为输入data_in数据流个数加上一个插入帧，否则表明输出数据的有效拍数与输入data_in的拍数相同
  reg                             flag_out_num;
  //对keep_in进行按位取反方便求keep_in中尾部0的个数
  wire    [DATA_BYTE_WD-1 : 0]    keep_in_conversion  ;
  
  assign  keep_in_conversion = ~keep_in;
  
  always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		   last_in_r 	        <= 0;
		   valid_insert_r 	    <= 0;
		   header_insert_r 	    <= 0;
		   data_in_r1 	        <= 0;
		   data_in_r2 	        <= 0;		
		end
	else
		begin
		   last_in_r 	        <= last_in;
		   valid_insert_r 	    <= valid_insert;
		   header_insert_r 	    <= header_insert;
		   data_in_r1 	        <= data_in;
		   data_in_r2 	        <= data_in_r1;	
		end
end
  
  
  
always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
 	   cnt1 <= 'd0;
 	else if (valid_insert)
 	   begin
	      case(keep_insert)
               8'b00000000  : cnt1 <= 'd0;
               8'b00000001  : cnt1 <= 'd1;
               8'b00000011  : cnt1 <= 'd2;
               8'b00000111  : cnt1 <= 'd3;
               8'b00001111  : cnt1 <= 'd4;
               8'b00011111  : cnt1 <= 'd5;
               8'b00111111  : cnt1 <= 'd6;
               8'b01111111  : cnt1 <= 'd7;
               8'b11111111  : cnt1 <= 'd8;
			   default      : cnt1 <= 'd0;
		  endcase
	   end
    else if (last_out)	
	   cnt1 <= 'd0;
	else
       cnt1 <= cnt1;
end 

always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
 	   cnt0 <= 'd0;
 	else if (last_in)
 	   begin
	      case(keep_in_conversion)
		       8'b00000000  : cnt0 <= 'd0;
               8'b00000001  : cnt0 <= 'd1;
               8'b00000011  : cnt0 <= 'd2;
               8'b00000111  : cnt0 <= 'd3;
               8'b00001111  : cnt0 <= 'd4;
               8'b00011111  : cnt0 <= 'd5;
               8'b00111111  : cnt0 <= 'd6;
               8'b01111111  : cnt0 <= 'd7;
               
			   default      : cnt0 <= 'd0;
		  endcase
	   end
    else if (last_out)	
	   cnt0 <= 'd0;
	else
       cnt0 <= cnt0;
end 

always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	begin
	   flag_out_num  <= 1'b0;
	end
 	else if (last_in_r && (cnt1 > cnt0))
 	   flag_out_num  <= 1'b1;
    
	else
       flag_out_num  <= 1'b0 ;
end 



always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	   begin
	      flag_patch  <= 1'b0;
	   end
 	else if (valid_insert_r)
 	   flag_patch  <= 1'b1;
    else if (last_in_r)	
	   begin
	      if(cnt1>cnt0)
		     flag_patch  <= 1'b1 ;
		  else
		     flag_patch  <= 1'b0 ;
	   end
	else if (flag_out_num)  
	   flag_patch  <= 1'b0 ;
	else
       flag_patch  <= flag_patch ;
end 



always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	   begin
	      data_out  <= 0;
	   end
 	else if (valid_insert_r)
 	   data_out <=  (header_insert_r << ((DATA_BYTE_WD-cnt1)*8)) + (data_in_r1 >>  (cnt1*8));                                 
    else if (flag_patch)	
	   data_out <=  (data_in_r2 << ((DATA_BYTE_WD-cnt1)*8)) + (data_in_r1 >>  (cnt1*8)); 
	else
       data_out <=  'd0;
end 

always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	   begin
	      keep_out  <= 'd0;
	   end
 	else if (valid_insert_r)
 	   keep_out  <= {DATA_BYTE_WD{1'b1}};
    else if (flag_patch && last_in_r)	
	   begin
	      if(cnt1>cnt0)
		     keep_out  <= {DATA_BYTE_WD{1'b1}};
		  else
		     keep_out  <= {DATA_BYTE_WD{1'b1}} << (cnt0-cnt1);                     
	   end
	else if(flag_out_num)
       keep_out <=   {DATA_BYTE_WD{1'b1}} << (DATA_BYTE_WD-(cnt1-cnt0));                            
	else if(last_out)
	   keep_out <= {DATA_BYTE_WD{1'b0}};
	else
	   keep_out <= keep_out;
end 

always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	   begin
	      last_out  <= 1'b0;
	   end
    else if (flag_patch && last_in_r)	
	   begin
	      if(cnt1>cnt0)
		     last_out  <= 1'b0;
		  else
		     last_out  <= 1'b1;
	   end
	else if(flag_out_num)
       last_out <= 1'b1;
	else
	   last_out <= 1'b0;
end 

always @ (posedge clk or negedge rst_n) 
begin
 	if(rst_n == 1'b0)
	   begin
	      valid_out  <= 1'b0;
	   end
    else if (valid_insert_r)	
	   begin
	      valid_out  <= 1'b1;
	   end
	else if(last_out)
       valid_out <= 1'b0;
	else
	   valid_out <= valid_out;
end 


endmodule








