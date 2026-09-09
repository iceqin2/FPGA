`timescale 1ns / 1ps

module ana_show(
	input					clk			,
	input 					rst_n		,
			
	input 					i_vld		,
	input		[23:0]		i_red		,
	input 		[23:0]		i_ir		,
	
	output	reg	[3:0]		o_dis_datx1	,
	output	reg	[3:0]		o_dis_datx2
    );
	
reg	[31:0]	time_cnt	;
reg	[23:0]	max_red_dat		;
reg	[23:0]	min_red_dat		;
reg	[23:0]	red_derta_dat	;
reg	[23:0]	ir_derta_dat	;
reg	[23:0]	max_ir_dat		;
reg	[23:0]	min_ir_dat		;

reg	[47:0]	mult_ans_1		;
wire	[63:0]	mult_ans_1x16		;
reg	[47:0]	mult_ans_2		;



reg			i_vld_dly		;
wire		user_vld		;

wire			sum_red_vld		;
wire	[31:0]	sum_red_dat		;
wire	[23:0]	aver_red_dat	;
wire			sum_ir_vld		;
wire	[31:0]	sum_ir_dat		;
wire	[23:0]	aver_ir_dat		;
wire	[23:0]	div_divder		;

wire	[31:0]	of_aver_red_vld	;
wire	[31:0]	of_aver_red_dat	;
wire	[31:0]	of_aver_ir_vld	;
wire	[31:0]	of_aver_ir_dat	;

wire	[31:0]	of_derta_red_vld	;
wire	[31:0]	of_derta_red_dat	;
wire	[31:0]	of_derta_ir_vld		;
wire	[31:0]	of_derta_ir_dat		;


wire			of_mux1_vld;
wire	[31:0]	of_mux1_dat;
wire			of_mux2_vld;
wire	[31:0]	of_mux2_dat;

wire			of_div_vld;
wire	[31:0]	of_div_dat;

wire			of_R2_vld;
wire	[31:0]	of_R2_dat;

wire			of_R2A_vld;
wire	[31:0]	of_R2A_dat;

wire			of_R1A_vld;
wire	[31:0]	of_R1A_dat;

wire			of_ADDx1_vld;
wire	[31:0]	of_ADDx1_dat;


wire			of_ANS_vld;
wire	[31:0]	of_ANS_dat;
wire			o_int_vld;
wire	[31:0]	o_int_dat;





wire			flag			;

assign flag = (time_cnt == 'd50_000_000);


always@(posedge clk)
begin
	i_vld_dly	<= i_vld;
end
assign user_vld = (!i_vld_dly &&i_vld);


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		time_cnt		<= 'd0;
		red_derta_dat	<= 'd0;
		ir_derta_dat	<= 'd0;
	end
	else if(time_cnt == 'd50_000_000)begin
		time_cnt		<= 'd0;
		red_derta_dat	<= max_red_dat - min_red_dat;
		ir_derta_dat	<= max_ir_dat - min_ir_dat;
	end
	else begin
		time_cnt	<= time_cnt + 1;
		red_derta_dat	<= red_derta_dat	;
		ir_derta_dat	<= ir_derta_dat	;
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		max_red_dat	<= 'd0;
	end
	else if(time_cnt == 'd50_000_000)begin
		max_red_dat	<= 'd0;
	end
	else if(max_red_dat < i_red && user_vld)begin
		max_red_dat	<= i_red ; 
	end
	else begin
		max_red_dat	<= max_red_dat;
	end
end


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		min_red_dat	<= 'hFFFFFF;
	end
	else if(time_cnt == 'd50_000_000)begin
		min_red_dat	<= 'hFFFFFF;
	end
	else if(min_red_dat > i_red&& user_vld)begin
		min_red_dat	<= i_red ; 
	end
	else begin
		min_red_dat	<= min_red_dat;
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		max_ir_dat	<= 'd0;
	end
	else if(time_cnt == 'd50_000_000)begin
		max_ir_dat	<= 'd0;
	end
	else if(max_ir_dat < i_ir&& user_vld)begin
		max_ir_dat	<= i_ir ; 
	end
	else begin
		max_ir_dat	<= max_ir_dat;
	end
end


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		min_ir_dat	<= 'hFFFFFF;
	end
	else if(time_cnt == 'd50_000_000)begin
		min_ir_dat	<= 'hFFFFFF;
	end
	else if(min_ir_dat > i_ir&& user_vld)begin
		min_ir_dat	<= i_ir ; 
	end
	else begin
		min_ir_dat	<= min_ir_dat;
	end
end


sum x1 (
  .aresetn				(rst_n				),// input wire aresetn//数据累加模块
  .aclk					(clk				),// input wire aclk
  .s_axis_data_tvalid	(user_vld			),  // input wire s_axis_data_tvalid
  .s_axis_data_tready	(					),  // output wire s_axis_data_tready
  .s_axis_data_tdata	(i_red				),    // input wire [23 : 0] s_axis_data_tdata
  .m_axis_data_tvalid	(sum_red_vld		),  // output wire m_axis_data_tvalid
  .m_axis_data_tdata 	(sum_red_dat		)    // output wire [31 : 0] m_axis_data_tdata
);


sum x2 (
  .aresetn				(rst_n				),                        // input wire aresetn
  .aclk					(clk				),                              // input wire aclk
  .s_axis_data_tvalid	(user_vld			),  // input wire s_axis_data_tvalid
  .s_axis_data_tready	(					),  // output wire s_axis_data_tready
  .s_axis_data_tdata	(i_ir				),    // input wire [23 : 0] s_axis_data_tdata
  .m_axis_data_tvalid	(sum_ir_vld			),  // output wire m_axis_data_tvalid
  .m_axis_data_tdata 	(sum_ir_dat			)    // output wire [31 : 0] m_axis_data_tdata
);

assign aver_red_dat = sum_red_dat[28:5];//平均值计算
assign aver_ir_dat 	= sum_ir_dat[28:5];


float_tf float_tf1 (
  .aclk					(clk					),                                  // input wire aclk//红光浮点转换模块
  .s_axis_a_tvalid		(flag					),            // input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),            // output wire s_axis_a_tready
  .s_axis_a_tdata		({8'd0,aver_red_dat}	),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid	(of_aver_red_vld		),  // output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),  // input wire m_axis_result_tready
  .m_axis_result_tdata	(of_aver_red_dat		)    // output wire [31 : 0] m_axis_result_tdata
);

float_tf float_tf2 (
  .aclk					(clk					),                                  // input wire aclk红外
  .s_axis_a_tvalid		(flag					),            // input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),            // output wire s_axis_a_tready
  .s_axis_a_tdata		({8'd0,aver_ir_dat}		),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid	(of_aver_ir_vld			),  // output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),  // input wire m_axis_result_tready
  .m_axis_result_tdata	(of_aver_ir_dat			)    // output wire [31 : 0] m_axis_result_tdata
);

float_tf float_tf3 (
  .aclk					(clk					),                                  // input wire aclk红光AC分量
  .s_axis_a_tvalid		(flag					),            // input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),            // output wire s_axis_a_tready
  .s_axis_a_tdata		({8'd0,red_derta_dat}	),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid	(of_derta_red_vld		),  // output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),  // input wire m_axis_result_tready
  .m_axis_result_tdata	(of_derta_red_dat		)    // output wire [31 : 0] m_axis_result_tdata
);

float_tf float_tf4 (
  .aclk					(clk					),                                  // input wire aclk红外AC分量
  .s_axis_a_tvalid		(flag					),            // input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),            // output wire s_axis_a_tready
  .s_axis_a_tdata		({8'd0,ir_derta_dat}	),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid	(of_derta_ir_vld		),  // output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),  // input wire m_axis_result_tready
  .m_axis_result_tdata	(of_derta_ir_dat		)    // output wire [31 : 0] m_axis_result_tdata
);

floating_mult floating_mult1 (
  .aclk					(clk					),// input wire aclk//公式执行浮点乘法红光DC和红外AC
  .s_axis_a_tvalid		(of_aver_red_vld		),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_aver_red_dat		),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_derta_ir_vld		),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(of_derta_ir_dat		),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_mux1_vld			),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_mux1_dat			) // output wire [31 : 0] m_axis_result_tdata
);

floating_mult floating_mult2 (
  .aclk					(clk					),// input wire aclk//红外DC和红光AC
  .s_axis_a_tvalid		(of_aver_ir_vld			),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_aver_ir_dat			),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_derta_red_vld		),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(of_derta_red_dat		),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_mux2_vld			),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_mux2_dat			) // output wire [31 : 0] m_axis_result_tdata
);

floating_div floating_div1 (
  .aclk					(clk					),                                  // input wire aclk除法
  .s_axis_a_tvalid		(of_mux1_vld			),            // input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),            // output wire s_axis_a_tready
  .s_axis_a_tdata		(of_mux1_dat			),              // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_mux2_vld			),            // input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),            // output wire s_axis_b_tready
  .s_axis_b_tdata		(of_mux2_dat			),              // input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_div_vld				),  // output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),  // input wire m_axis_result_tready
  .m_axis_result_tdata	(of_div_dat				)    // output wire [31 : 0] m_axis_result_tdata
);


floating_mult floating_multf (
  .aclk					(clk					),// input wire aclk计算R的平方
  .s_axis_a_tvalid		(of_div_vld				),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_div_dat				),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_div_vld				),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(of_div_dat				),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_R2_vld				),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_R2_dat				) // output wire [31 : 0] m_axis_result_tdata
);
//-45.06		C2343D71
//30.354		41F2D4FE
//94.845 		42BDB0A4


floating_mult floating_multR2c (
  .aclk					(clk					),// input wire aclk计算-45.06(a)乘R的平方
  .s_axis_a_tvalid		(of_R2_vld				),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_R2_dat				),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_R2_vld				),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(32'hC2343D71			),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_R2A_vld				),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_R2A_dat				) // output wire [31 : 0] m_axis_result_tdata
);


floating_mult floating_multR1c (
  .aclk					(clk					),// input wire aclk计算30.354(b)乘R的平方
  .s_axis_a_tvalid		(of_div_vld				),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_div_dat				),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_div_vld				),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(32'h41F2D4FE			),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_R1A_vld				),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_R1A_dat				) // output wire [31 : 0] m_axis_result_tdata
);


floating_add floating_add1 (
  .aclk					(clk					),// input wire aclk计算bR+c(94.845)
  .s_axis_a_tvalid		(of_R1A_vld				),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_R1A_dat				),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_R1A_vld				),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(32'h42BDB0A4			),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_ADDx1_vld			),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_ADDx1_dat			) // output wire [31 : 0] m_axis_result_tdata
);

floating_add floating_add2 (
  .aclk					(clk					),// input wire aclk计算aR的平方加bR+ac即为血氧饱和度
  .s_axis_a_tvalid		(of_R2A_vld				),// input wire s_axis_a_tvalid
  .s_axis_a_tready		(						),// output wire s_axis_a_tready
  .s_axis_a_tdata		(of_R2A_dat				),// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid		(of_ADDx1_vld			),// input wire s_axis_b_tvalid
  .s_axis_b_tready		(						),// output wire s_axis_b_tready
  .s_axis_b_tdata		(of_ADDx1_dat			),// input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid	(of_ANS_vld				),// output wire m_axis_result_tvalid
  .m_axis_result_tready	('d1					),// input wire m_axis_result_tready
  .m_axis_result_tdata	(of_ANS_dat				) // output wire [31 : 0] m_axis_result_tdata
);

floating_point_0 floating_point_0x (
  .aclk(clk),                                  // input wire aclk转化为整数
  .s_axis_a_tvalid(of_ANS_vld),            // input wire s_axis_a_tvalid
  .s_axis_a_tready(),            // output wire s_axis_a_tready
  .s_axis_a_tdata(of_ANS_dat),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(o_int_vld),  // output wire m_axis_result_tvalid
  .m_axis_result_tready('d1),  // input wire m_axis_result_tready
  .m_axis_result_tdata(o_int_dat)    // output wire [31 : 0] m_axis_result_tdata
);



ila_0 your_instance_name (
	.clk(clk), // input wire clk进行对ila的调试，进行在线检测


	.probe0({
		o_int_vld		,
	    o_int_dat		,
		of_ANS_vld		,
		of_ANS_dat		,
		red_derta_dat	,
		ir_derta_dat	,
		aver_red_dat	,
	    aver_ir_dat 
	}) // input wire [127:0] probe0
);	




always@(posedge clk or negedge rst_n)//将血氧整数结果转化为数码管的个位和十位数据
begin
	if(!rst_n)begin
		o_dis_datx1 <= 'd0;
		o_dis_datx2 <= 'd0;
	end
	else if(o_int_dat < 100 && !o_int_dat[32] && o_int_vld)begin
		o_dis_datx1 <= o_int_dat/10 ;
		o_dis_datx2 <= o_int_dat%10 ;
	end
	else if(o_int_vld)begin
		o_dis_datx1 <= 'd15 ;
		o_dis_datx2 <= 'd15 ;
	end
	else begin
		o_dis_datx1 <= o_dis_datx1 ;
		o_dis_datx2 <= o_dis_datx2 ;
	end
end


endmodule
