`timescale 1ns / 1ps

module max30102_driver(
	input 					clk_50				,
	input 					clk					,
	input 					rst_n				,
			
	input 					i_start_en			,//����ģ�飬ͨ��״̬�����豸�Ĵ���д������
	input					io_intr				,
	
	//iic_phy
	output 	reg				iic_start			,//iic启动信号
	output					iic_16b_8b_opt		,//iic字地�?选择(16b/8b) 1:16bit   	0:8bit  （start同步输入�?
	output	reg				iic_rd_wr_opt		,//读写方向选择 0：写   1：读 				（start同步输入�?
	output	reg				iic_1Byte_6Byte		,//iic读写长度选择0:选择1Byte 1:选择6Byte
	output			[6:0]	iic_slave_addr		,//iic从机地址								（start同步输入�?
	output	reg		[15:0]	iic_addr			,//iic内部寄存器地�?						（start同步输入�?
	output	reg		[7:0]	iic_wr_dat			,//iic写入数据								（start同步输入�?
	input	[7:0]			iic_rd_dat			,//读数�?
	input 	[47:0]			iic_rd_dat_6B		,
	input					iic_flash			,//读有�?
	
	output					o_vld				,
	output	[23:0]			o_red_dat			,
	output	[23:0]			o_ir_dat			
    );

//寄存器地�?定义
localparam REG_INTR_STATUS_1 	 = 16'h00;
localparam REG_INTR_STATUS_2 	 = 16'h01;
localparam REG_INTR_ENABLE_1 	 = 16'h02;
localparam REG_INTR_ENABLE_2 	 = 16'h03;
localparam REG_FIFO_WR_PTR 		 = 16'h04;
localparam REG_OVF_COUNTER 		 = 16'h05;
localparam REG_FIFO_RD_PTR 		 = 16'h06;
localparam REG_FIFO_DATA 		 = 16'h07;
localparam REG_FIFO_CONFIG 		 = 16'h08;
localparam REG_MODE_CONFIG 		 = 16'h09;
localparam REG_SPO2_CONFIG		 = 16'h0A;
localparam REG_LED1_PA 			 = 16'h0C;
localparam REG_LED2_PA 			 = 16'h0D;
localparam REG_PILOT_PA 		 = 16'h10;
localparam REG_MULTI_LED_CTRL1 	 = 16'h11;
localparam REG_MULTI_LED_CTRL2 	 = 16'h12;
localparam REG_TEMP_INTR 		 = 16'h1F;
localparam REG_TEMP_FRAC 		 = 16'h20;
localparam REG_TEMP_CONFIG 		 = 16'h21;
localparam REG_PROX_INT_THRESH 	 = 16'h30;
localparam REG_REV_ID 			 = 16'hFE;
localparam REG_PART_ID 			 = 16'hFF;

//状�?�机定义
localparam	IDLE				= 8'd0 ;
localparam	WR_RST				= 8'd1 ;
localparam	WR_RST_WAIT			= 8'd2 ;
localparam	WR_INTR_1			= 8'd3 ;
localparam	WR_INTR_1_WAIT		= 8'd4 ;
localparam	WR_INTR_2			= 8'd5 ;
localparam	WR_INTR_2_WAIT		= 8'd6 ;
localparam	WR_FIFO_WR			= 8'd7 ;
localparam	WR_FIFO_WR_WAIT		= 8'd8 ;
localparam	WR_OVF_COUNTER		= 8'd9 ;
localparam	WR_OVF_COUNTER_WAIT	= 8'd10;
localparam	WR_FIFO_RD			= 8'd11;
localparam	WR_FIFO_RD_WAIT		= 8'd12;
localparam	WR_FIFO_CONFIG		= 8'd13;
localparam	WR_FIFO_CONFIG_WAIT	= 8'd14;
localparam	WR_MODE_CONFIG		= 8'd15;
localparam	WR_MODE_CONFIG_WAIT	= 8'd16;
localparam	WR_SPO2_CONFIG		= 8'd17;
localparam	WR_SPO2_CONFIG_WAIT	= 8'd18;
localparam	WR_LED1_PA			= 8'd19;
localparam	WR_LED1_PA_WAIT		= 8'd20;
localparam	WR_LED2_PA			= 8'd21;
localparam	WR_LED2_PA_WAIT		= 8'd22;
localparam	INTR_WAIT			= 8'd23;
localparam	WR_RD_XT1			= 8'd24;
localparam	WR_RD_XT1_WAIT		= 8'd25;
localparam	WR_RD_XT2			= 8'd26;
localparam	WR_RD_XT2_WAIT		= 8'd27;
localparam	WR_RD_X1			= 8'd28;
localparam	WR_RD_X1_WAIT		= 8'd29;
localparam	WR_RD_X2			= 8'd30;
localparam	WR_RD_X2_WAIT		= 8'd31;
localparam	WR_RD_X3			= 8'd32;
localparam	WR_RD_X3_WAIT		= 8'd33;
localparam	WR_RD_X4			= 8'd34;
localparam	WR_RD_X4_WAIT		= 8'd35;
localparam	WR_RD_X5			= 8'd36;
localparam	WR_RD_X5_WAIT		= 8'd37;
localparam	WR_RD_X6			= 8'd38;
localparam	WR_RD_X6_WAIT		= 8'd39;
localparam	END_WAIT			= 8'd40;


reg		[47:0]		TRUE_DATA	;

reg		[7:0]		INIT_X1		;
reg		[7:0]		INIT_X2		;

	
reg			[7:0 ]		state		;
reg			[7:0]		next_state	;
reg			[15:0]		end_cnt		;

assign iic_16b_8b_opt = 'd0;
assign iic_slave_addr = 7'h57;


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		state	<= IDLE;
	end
	else begin
		state	<= next_state	;
	end
end		
	
always@(*)
begin
	case(state)
		IDLE				:	next_state = (i_start_en)?WR_RST:IDLE;
		WR_RST				:	next_state = WR_RST_WAIT;
		WR_RST_WAIT			:	next_state = (iic_flash)?WR_INTR_1:WR_RST_WAIT;
		WR_INTR_1			:	next_state = WR_INTR_1_WAIT;
		WR_INTR_1_WAIT		:	next_state = (iic_flash)?WR_INTR_2:WR_INTR_1_WAIT;
		WR_INTR_2			:	next_state = WR_INTR_2_WAIT;
		WR_INTR_2_WAIT		:	next_state = (iic_flash)?WR_FIFO_WR:WR_INTR_2_WAIT;
		WR_FIFO_WR			: 	next_state = WR_FIFO_WR_WAIT;
		WR_FIFO_WR_WAIT		:	next_state = (iic_flash)?WR_OVF_COUNTER:WR_FIFO_WR_WAIT;
		WR_OVF_COUNTER		: 	next_state = WR_OVF_COUNTER_WAIT;
		WR_OVF_COUNTER_WAIT	:	next_state = (iic_flash)?WR_FIFO_RD:WR_OVF_COUNTER_WAIT;
		WR_FIFO_RD			: 	next_state = WR_FIFO_RD_WAIT;
		WR_FIFO_RD_WAIT		:	next_state = (iic_flash)?WR_FIFO_CONFIG:WR_FIFO_RD_WAIT;
		WR_FIFO_CONFIG		: 	next_state = WR_FIFO_CONFIG_WAIT;
		WR_FIFO_CONFIG_WAIT	:	next_state = (iic_flash)?WR_MODE_CONFIG:WR_FIFO_CONFIG_WAIT;
		WR_MODE_CONFIG		: 	next_state = WR_MODE_CONFIG_WAIT;
		WR_MODE_CONFIG_WAIT	:	next_state = (iic_flash)?WR_SPO2_CONFIG:WR_MODE_CONFIG_WAIT;
		WR_SPO2_CONFIG		: 	next_state = WR_SPO2_CONFIG_WAIT;
		WR_SPO2_CONFIG_WAIT	:	next_state = (iic_flash)?WR_LED1_PA:WR_SPO2_CONFIG_WAIT;		
		WR_LED1_PA			: 	next_state = WR_LED1_PA_WAIT;
		WR_LED1_PA_WAIT		:	next_state = (iic_flash)?WR_LED2_PA:WR_LED1_PA_WAIT;	
		WR_LED2_PA			: 	next_state = WR_LED2_PA_WAIT;
		WR_LED2_PA_WAIT		:	next_state = (iic_flash)?INTR_WAIT:WR_LED2_PA_WAIT;		
		INTR_WAIT			:	next_state = (!io_intr)?WR_RD_XT1:INTR_WAIT;
		WR_RD_XT1			: 	next_state = WR_RD_XT1_WAIT;
		WR_RD_XT1_WAIT		:	next_state = (iic_flash)?WR_RD_XT2:WR_RD_XT1_WAIT;
		WR_RD_XT2			: 	next_state = WR_RD_XT2_WAIT;
		WR_RD_XT2_WAIT		:	next_state = (iic_flash)?WR_RD_X1:WR_RD_XT2_WAIT;
		WR_RD_X1			: 	next_state = WR_RD_X1_WAIT;
		WR_RD_X1_WAIT		:	next_state = (iic_flash)?END_WAIT:WR_RD_X1_WAIT;	
		WR_RD_X2			: 	next_state = WR_RD_X2_WAIT;
		WR_RD_X2_WAIT		:	next_state = (iic_flash)?WR_RD_X3:WR_RD_X2_WAIT;
		WR_RD_X3			: 	next_state = WR_RD_X3_WAIT;
		WR_RD_X3_WAIT		:	next_state = (iic_flash)?WR_RD_X4:WR_RD_X3_WAIT;	
		WR_RD_X4			: 	next_state = WR_RD_X4_WAIT;
		WR_RD_X4_WAIT		:	next_state = (iic_flash)?WR_RD_X5:WR_RD_X4_WAIT;		
		WR_RD_X5			: 	next_state = WR_RD_X5_WAIT;
		WR_RD_X5_WAIT		:	next_state = (iic_flash)?WR_RD_X6:WR_RD_X5_WAIT;	
		WR_RD_X6			: 	next_state = WR_RD_X6_WAIT;
		WR_RD_X6_WAIT		:	next_state = (iic_flash)?END_WAIT:WR_RD_X6_WAIT;	
		END_WAIT			:	next_state = (!io_intr && end_cnt == 'd60)?WR_RD_XT1:END_WAIT;
				
		default	:			next_state = IDLE;
	endcase	
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		iic_start      <= 'd0;
		iic_rd_wr_opt  <= 'd0;
		iic_addr       <= 'd0;
		iic_wr_dat     <= 'd0;
		end_cnt		   <= 'd0;
		iic_1Byte_6Byte<= 'd0;
	end
	else begin
		case(next_state)
			IDLE:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_RST:begin//设定芯片复位
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_MODE_CONFIG;
				iic_wr_dat     <= 'h40;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_RST_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_INTR_1:begin//中断使能A_FULL和PPG_RDY
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_INTR_ENABLE_1;
				iic_wr_dat     <= 'hC0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_INTR_1_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_INTR_2:begin//中断使能A_FULL和PPG_RDY
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_INTR_ENABLE_2;
				iic_wr_dat     <= 'h00;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_INTR_2_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_WR:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_FIFO_WR_PTR;
				iic_wr_dat     <= 'h00;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_WR_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_OVF_COUNTER:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_OVF_COUNTER;
				iic_wr_dat     <= 'h00;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_OVF_COUNTER_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_RD:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_FIFO_RD_PTR;
				iic_wr_dat     <= 'h00;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_RD_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_CONFIG:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_FIFO_CONFIG;
				iic_wr_dat     <= 'h0f;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_FIFO_CONFIG_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_MODE_CONFIG:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_MODE_CONFIG;
				iic_wr_dat     <= 'h03;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_MODE_CONFIG_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_SPO2_CONFIG:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_SPO2_CONFIG;
				iic_wr_dat     <= 'h27;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_SPO2_CONFIG_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_LED1_PA:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_LED1_PA;
				iic_wr_dat     <= 'h32;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_LED1_PA_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_LED2_PA:begin
				iic_start      <= 'd1;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= REG_LED2_PA;
				iic_wr_dat     <= 'h32;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_LED2_PA_WAIT:begin
				iic_start      <= 'd0;
				iic_rd_wr_opt  <= 'd0;
				iic_addr       <= 'd0;
				iic_wr_dat     <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end/////////////到此初始化完�?////////////////////////////
			WR_RD_XT1:begin
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_INTR_STATUS_1;
				iic_wr_dat     	<= 'h00;
				end_cnt		    <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_RD_XT1_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end	
			WR_RD_XT2:begin
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_INTR_STATUS_2;
				iic_wr_dat     	<= 'h00;
				end_cnt		    <= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end
			WR_RD_XT2_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
				iic_1Byte_6Byte<= 'd0;
			end	
			WR_RD_X1:begin
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
				end_cnt		    <= 'd0;
				iic_1Byte_6Byte <= 'd1;
			end
			WR_RD_X1_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end	
			WR_RD_X2:begin	
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
				
			end
			WR_RD_X2_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end	
			WR_RD_X3:begin	
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
			end
			WR_RD_X3_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end	
			WR_RD_X4:begin	
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
			end
			WR_RD_X4_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end	
			WR_RD_X5:begin	
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
			end
			WR_RD_X5_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end	
			WR_RD_X6:begin	
				iic_start      	<= 'd1;
				iic_rd_wr_opt  	<= 'd1;
				iic_addr       	<= REG_FIFO_DATA;
				iic_wr_dat     	<= 'h00;
			end
			WR_RD_X6_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
			end
			END_WAIT:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
				end_cnt			<= end_cnt + 1;
			end
			default:begin
				iic_start      	<= 'd0;
				iic_rd_wr_opt  	<= 'd0;
				iic_addr       	<= 'd0;
				iic_wr_dat     	<= 'd0;
				end_cnt		   	<= 'd0;
				iic_1Byte_6Byte <= iic_1Byte_6Byte;
			end
		endcase
	end
end
				
	

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		TRUE_DATA	<= 'd0;
	end
	else if(state == WR_RD_X1_WAIT && iic_flash)begin
		TRUE_DATA	<= iic_rd_dat_6B;
	end
	else begin
		TRUE_DATA	<= TRUE_DATA;
	end
end	


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		INIT_X1	<= 'd0;
	end
	else if(state == WR_RD_XT1_WAIT && iic_flash)begin
		INIT_X1 <= iic_rd_dat;
	end
	else begin
		INIT_X1	<= INIT_X1;
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		INIT_X2	<= 'd0;
	end
	else if(state == WR_RD_XT2_WAIT && iic_flash)begin
		INIT_X2 <= iic_rd_dat;
	end
	else begin
		INIT_X2	<= INIT_X2;
	end
end			
						
	    				
assign o_vld		= 	(state == END_WAIT && !io_intr && end_cnt == 'd60);				
assign o_red_dat	= 	TRUE_DATA[47:24];	
assign o_ir_dat		= 	TRUE_DATA[23:0] ;

// ila_0 your_instance_name (
	// .clk(clk_50), // input wire clk


	// .probe0({
		// INIT_X1		,
		// INIT_X2		,
		// o_vld		,
	    // o_red_dat	,
	    // o_ir_dat	,
		// io_intr		,
		// state		,
		// iic_rd_dat_6B,
		// next_state	
	// }) // input wire [127:0] probe0
// );



endmodule
