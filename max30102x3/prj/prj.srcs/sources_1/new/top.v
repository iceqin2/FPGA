`timescale 1ns / 1ps
/*
����ģ�飬��50mhzʱ�ӷ�Ƶ�����Ӹ�����ģ��
*/
module top(
	input		clk_50m		,//输入50M时钟
	input 		rst_n		,//复位信号
		
	input		io_intr		,
	inout 		sda			,
	output		scl			,
	
	output	[3:0]o_dis_datx1,
	output	[3:0]o_dis_datx2
	
	
	
    );
	
wire				iic_start		;		
wire				iic_16b_8b_opt	;		
wire				iic_rd_wr_opt	;		
wire		[6:0]	iic_slave_addr	;		
wire		[15:0]	iic_addr		;		
wire		[7:0]	iic_wr_dat		;		
wire		[7:0]	iic_rd_dat		;		
wire				iic_flash		;		
wire				iic_1Byte_6Byte	;

wire		[47:0]	iic_rd_dat_6B	;
	
	
wire				o_vld			;
wire		[17:0]	o_red_dat		;
wire		[17:0]	o_ir_dat		;

wire				iic_user_clk	;

reg			[15:0]	cnt	;

always@(posedge iic_user_clk or negedge rst_n)
begin
	if(!rst_n)begin
		cnt	<= 'd0;
	end
	else if(cnt == 'd65535)begin
		cnt	<= cnt;
	end
	else begin
		cnt	<= cnt + 1;
	end
end

	
	
max30102_driver(
	.clk_50					(clk_50m			),
	.clk					(iic_user_clk		),
	.rst_n					(rst_n				),
	.io_intr				(io_intr			),	
	.i_start_en				((cnt=='d60000)		),//工作使能
	//iic_phy
	.iic_start				(iic_start			),//iic启动信号
	.iic_16b_8b_opt			(iic_16b_8b_opt		),//iic字地�?选择(16b/8b) 1:16bit   	0:8bit  （start同步输入�?
	.iic_rd_wr_opt			(iic_rd_wr_opt		),//读写方向选择 0：写   1：读 				（start同步输入�?
	.iic_1Byte_6Byte		(iic_1Byte_6Byte	),//iic读写长度选择0:选择1Byte 1:选择6Byte
	.iic_slave_addr			(iic_slave_addr		),//iic从机地址								（start同步输入�?
	.iic_addr				(iic_addr			),//iic内部寄存器地�?							（start同步输入�?
	.iic_wr_dat				(iic_wr_dat			),//iic写入数据								（start同步输入�?
	.iic_rd_dat				(iic_rd_dat			),//读数�?
	.iic_rd_dat_6B			(iic_rd_dat_6B		),//读数�?
	.iic_flash				(iic_flash			),//读有�?
	
	.o_vld					(o_vld				),
	.o_red_dat				(o_red_dat			),
	.o_ir_dat				(o_ir_dat			)
    );
	
	
iic_phy u_iic_phy(
	.clk					(clk_50m			),//工作时钟
	.rst_n				 	(rst_n				),//复位信号
			
	.iic_start				(iic_start			),//iic启动信号
	.iic_16b_8b_opt			(iic_16b_8b_opt		),//iic字地�?选择(16b/8b) 1:16bit   	0:8bit  （start同步输入�?
	.iic_rd_wr_opt			(iic_rd_wr_opt		),//读写方向选择 0：写   1：读 				（start同步输入�?
	.iic_1Byte_6Byte		(iic_1Byte_6Byte	),//iic读写长度选择0:选择1Byte 1:选择6Byte
	.iic_slave_addr			(iic_slave_addr		),//iic从机地址								（start同步输入�?
	.iic_addr				(iic_addr			),//iic内部寄存器地�?						（start同步输入�?
	.iic_wr_dat				(iic_wr_dat			),//iic写入数据								（start同步输入�?
	.iic_rd_dat				(iic_rd_dat			),//iic读出数据
	.iic_rd_dat_6B			(iic_rd_dat_6B		),//iic读出数据
	.iic_flash				(iic_flash			),//iic完成�?次数据后操作
	.iic_ack				(					),//iic应答信号
	.iic_error				(					),//iic错误信号
	//iic输出数据
	.iic_user_clk			(iic_user_clk		),//输出iic时钟
	//phy
	.scl					(scl				),//时钟�?
	.sda					(sda				) //数据�?
	
    );
	
	
ana_show xxana_show(
	.clk			(clk_50m	),
	.rst_n			(rst_n		),
	.i_vld			(o_vld		),
	.i_red			(o_red_dat	),
	.i_ir			(o_ir_dat	),
	.o_dis_datx1	(o_dis_datx2),
	.o_dis_datx2    (o_dis_datx1)
    );
	

	
endmodule
