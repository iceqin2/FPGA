`timescale 1ns / 1ps
//������ģ�飬��scl��sda����������i2cЭ��

//7位的地址位和�?位的读写�?
module iic_phy#(
	parameter	CLK_FREQ = 'd50_000_000,
	parameter	I2C_FREQ = 'd250_000
)(
	input 					clk					,//工作时钟
	input 					rst_n				,//复位信号
			
	input 					iic_start			,//iic启动信号
	input					iic_16b_8b_opt		,//iic字地�?选择(16b/8b) 1:16bit   	0:8bit  （start同步输入�?
	input					iic_rd_wr_opt		,//读写方向选择 0：写   1：读 				（start同步输入�?
	input					iic_1Byte_6Byte		,//iic读写长度选择0:选择1Byte 1:选择6Byte
	input			[6:0]	iic_slave_addr		,//iic从机地址								（start同步输入�?
	input			[15:0]	iic_addr			,//iic内部寄存器地�?						（start同步输入�?
	input			[7:0]	iic_wr_dat			,//iic写入数据								（start同步输入�?
	output	reg		[7:0]	iic_rd_dat			,//iic读出数据
	output	reg		[47:0]	iic_rd_dat_6B		,//iic读出数据6Bytes
	output	reg				iic_flash			,//iic完成�?次数据后操作
	output	reg				iic_ack				,//iic应答信号
	output 	reg				iic_error			,//iic错误信号
	//iic输出数据
	output	reg				iic_user_clk		,//输出iic时钟
	//phy
	output	reg				scl					,//时钟�?
	inout 					sda					 //数据�?
	
    );
	
localparam				CLK_DIV = (CLK_FREQ/I2C_FREQ)>>2	;//数据分频系数,用于从创建分频时�?

localparam				IDLE					= 	8'd0		;//空闲状�??
localparam				SEND_SLAVE_ADDR 		= 	8'd1		;//发�?�开始标�?
localparam				SEND_ADDR_HIGH 			= 	8'd2		;//发�?�高地址
localparam				SEND_ADDR_LOW 			= 	8'd3		;//发�?�低地址
localparam				SEND_DATA		 		= 	8'd4		;//发�?�数�?
localparam				END						= 	8'd5		;//完成�?次数据传�?
localparam				SEND_READ_START			= 	8'd6		;//发�?�读数据请求
localparam				READ_DATA				= 	8'd7		;//等待数据应答
localparam				READ_DATA_6BYTES		= 	8'd8		;//等待数据应答

reg		[7:0]			state				;//状�?�机
reg		[7:0]			next_state			;//下一次状�?

reg		[15:0]			div_clk_cnt			;//时钟分频计数

reg						user_16b_8b_opt		;//寄存器地�?位宽选择锁定信号
reg						user_rd_wr_opt		;//读写方向锁定信号
reg		[6:0]			user_slave_addr		;//从机地址锁定信号
reg		[15:0]			user_addr			;//寄存器地�?锁定信号
reg		[7:0]			user_wr_dat			;//写数据锁定信号锁定信�?	
reg						user_1Byte_6Byte	;//写数据锁定信号锁定信�?	

reg		[15:0]			step_cnt			;//步数计数
reg						step_done			;//每一步的完成信号

reg						user_rw_done		;//实际读写方向 0：写   1：读 
wire					sda_i				;//iic数据输入
reg						sda_o				;//iic数据输出

assign 	sda 	= (!user_rw_done)?sda_o:1'bz;
assign 	sda_i 	= sda;
//创建分频时钟
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		iic_user_clk 	<= 'd1;
		div_clk_cnt 	<= 'd0;
	end
	else if(div_clk_cnt == ((CLK_DIV>>1) - 'd1))begin
		iic_user_clk 	<= ~iic_user_clk;
		div_clk_cnt 	<= 'd0;
	end
	else begin
		iic_user_clk 	<= iic_user_clk;
		div_clk_cnt 	<= div_clk_cnt + 'd1;
	end
end

//锁定信号
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		user_16b_8b_opt		<= 'd0;
		user_rd_wr_opt		<= 'd0;
		user_slave_addr		<= 'd0;
		user_addr			<= 'd0;
		user_wr_dat			<= 'd0;
		user_1Byte_6Byte	<= 'd0;
	end
	else if(iic_start) begin
		user_16b_8b_opt		<= iic_16b_8b_opt	;
		user_rd_wr_opt		<= iic_rd_wr_opt	;
		user_slave_addr		<= iic_slave_addr	;
		user_addr			<= iic_addr			;
		user_wr_dat			<= iic_wr_dat		;
		user_1Byte_6Byte	<= iic_1Byte_6Byte	;
	end
	else begin
		user_16b_8b_opt		<= user_16b_8b_opt	;
		user_rd_wr_opt		<= user_rd_wr_opt	;
		user_slave_addr		<= user_slave_addr	;
		user_addr			<= user_addr		;
		user_wr_dat			<= user_wr_dat		;
		user_1Byte_6Byte	<= iic_1Byte_6Byte	;
	end
end

//状�?�机
always@(posedge iic_user_clk or negedge rst_n)
begin
	if(!rst_n)begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
	end
end


always@(*)
begin
	case(state)
		IDLE:					next_state = (iic_start) ? SEND_SLAVE_ADDR:IDLE					;
		SEND_SLAVE_ADDR:begin
			if(step_done && user_16b_8b_opt)begin
				next_state = SEND_ADDR_HIGH;
			end
			else if(step_done)begin
				next_state = SEND_ADDR_LOW;
			end
			// else if(iic_error)begin
				// next_state = IDLE;
			// end
			else begin
				next_state = SEND_SLAVE_ADDR;
			end
		end
		SEND_ADDR_HIGH:begin
			if(step_done)begin
				next_state = SEND_ADDR_LOW	;
			end
			// else if(iic_error)begin
				// next_state = IDLE			;
			// end
			else begin
				next_state = SEND_ADDR_HIGH	;
			end
			next_state = (step_done) ? SEND_ADDR_LOW:SEND_ADDR_HIGH	;
		end
		SEND_ADDR_LOW:begin
			if(step_done && user_rd_wr_opt)begin//读数�?
				next_state = SEND_READ_START;
			end
			else if(step_done)begin//写数�?
				next_state = SEND_DATA;
			end
			else begin
				next_state = SEND_ADDR_LOW;
			end
		end	
		SEND_READ_START:		next_state = (step_done) ? ((user_1Byte_6Byte)?READ_DATA_6BYTES:READ_DATA):SEND_READ_START	;
		READ_DATA_6BYTES:		next_state = (step_done) ? END:READ_DATA_6BYTES	;
		READ_DATA:				next_state = (step_done) ? END:READ_DATA		;
		SEND_DATA:				next_state = (step_done) ? END:SEND_DATA							;
		END:					next_state = (step_done) ? IDLE:END									;
		default:next_state = IDLE;
	endcase
end

//状�?�机服务信号
always@(posedge iic_user_clk or negedge rst_n)
begin
	if(!rst_n)begin//表示停止
		step_cnt		<= 'd0;//步进计数
		step_done		<= 'd0;//每一步完成信�?
		iic_error		<= 'd0;//iic错误信号
		iic_ack			<= 'd0;//iic应答信号
		scl				<= 'd1;//时钟线拉�?
		user_rw_done	<= 'd0;//表示数据输出
		sda_o			<= 'd1;//数据拉高
		iic_rd_dat		<= 'd0;//读取的数�?
		iic_rd_dat_6B	<= 'd0;//读出数据6B
		iic_flash		<= 'd0;//iic完成标志
	end
	else begin
		step_done		<= 'd0;
		iic_error		<= 'd0;
		step_cnt		<= step_cnt + 1;//步进计数
		case(state)
			IDLE:begin
				step_cnt		<= 'd0;//步进计数
				step_done		<= 'd0;//每一步完成信�?
				iic_ack			<= 'd0;//iic应答信号
				scl				<= 'd1;//时钟线拉�?
				user_rw_done	<= 'd0;//表示数据输出
				sda_o			<= 'd1;//数据拉高
				// iic_rd_dat		<= 'd0;//读取的数�?
				iic_flash		<= 'd0;//iic完成表示
			end
			SEND_SLAVE_ADDR:begin
				case(step_cnt)
					'd1:	sda_o	<= 'd0;//发�?�起始信�?
					'd3:	scl 	<= 'd0;
					'd4:	sda_o	<= user_slave_addr[6];
					'd5:	scl		<= 'd1;
					'd7:	scl		<= 'd0;
					'd8:	sda_o	<= user_slave_addr[5];
					'd9:	scl		<= 'd1;
					'd11:	scl		<= 'd0;
					'd12:	sda_o	<= user_slave_addr[4];
					'd13:	scl		<= 'd1;
					'd15:	scl		<= 'd0;
					'd16:	sda_o	<= user_slave_addr[3];
					'd17:	scl		<= 'd1;
					'd19:	scl		<= 'd0;
					'd20:	sda_o	<= user_slave_addr[2];
					'd21:	scl		<= 'd1;
					'd23:	scl		<= 'd0;
					'd24:	sda_o	<= user_slave_addr[1];
					'd25:	scl		<= 'd1;
					'd27:	scl		<= 'd0;
					'd28:	sda_o	<= user_slave_addr[0];
					'd29:	scl		<= 'd1;
					'd31:	scl		<= 'd0;
					'd32:	sda_o 	<= 'd0;
					'd33:	scl		<= 'd1;
					'd35:	scl		<= 'd0;
					'd36:	begin
						sda_o		<= 'd1;
						user_rw_done<= 'd1;
					end
					'd37:	scl 	<= 'd1;
					'd38:	begin
						step_done 	<= 'd1;
						if(!sda_i)begin
							iic_ack 	<= 'd1;
						end
						else begin
							iic_error	<= 'd1;
						end
					end
					'd39:begin
						scl 		<= 'd0;
						step_cnt 	<= 'd0;
					end
				endcase
			end
			SEND_ADDR_HIGH:begin
				case(step_cnt)
					'd0:begin
						user_rw_done <= 'd0;
						sda_o		 <= user_addr[15];
					end
					'd1:scl 		 <= 'd1;
					'd3:scl			 <= 'd0;
					'd4:sda_o		 <= user_addr[14];
					'd5:scl			 <= 'd1;
					'd7:scl			 <= 'd0;
					'd8:sda_o		 <= user_addr[13];
					'd9:scl			 <= 'd1;
					'd11:scl		 <= 'd0;
					'd12:sda_o		 <= user_addr[12];
					'd13:scl		 <= 'd1;
					'd15:scl		 <= 'd0;
					'd16:sda_o		 <= user_addr[11];
					'd17:scl		 <= 'd1;
					'd19:scl		 <= 'd0;
					'd20:sda_o		 <= user_addr[10];
					'd21:scl		 <= 'd1;
					'd23:scl		 <= 'd0;
					'd24:sda_o		 <= user_addr[9];
					'd25:scl		 <= 'd1;
					'd27:scl		 <= 'd0;
					'd28:sda_o		 <= user_addr[8];
					'd29:scl		 <= 'd1;
					'd31:scl		 <= 'd0;
					'd32:begin
						user_rw_done <= 'd1;
						sda_o		 <= 'd0;
					end
					'd33:scl		 <= 'd1;
					'd34:begin
						step_done 	 <= 'd1;
						if(!sda_i)begin
							iic_ack 	<= 'd1;
						end
						else begin
							iic_error	<= 'd1;
						end
					end
					'd35:begin
						scl 		 <= 'd0;
						step_cnt	 <= 'd0;
					end
				endcase
			end
			SEND_ADDR_LOW:begin
				case(step_cnt)
					'd0:begin
						user_rw_done <= 'd0;
						sda_o		 <= user_addr[7];
					end
					'd1:scl 		 <= 'd1;
					'd3:scl			 <= 'd0;
					'd4:sda_o		 <= user_addr[6];
					'd5:scl			 <= 'd1;
					'd7:scl			 <= 'd0;
					'd8:sda_o		 <= user_addr[5];
					'd9:scl			 <= 'd1;
					'd11:scl		 <= 'd0;
					'd12:sda_o		 <= user_addr[4];
					'd13:scl		 <= 'd1;
					'd15:scl		 <= 'd0;
					'd16:sda_o		 <= user_addr[3];
					'd17:scl		 <= 'd1;
					'd19:scl		 <= 'd0;
					'd20:sda_o		 <= user_addr[2];
					'd21:scl		 <= 'd1;
					'd23:scl		 <= 'd0;
					'd24:sda_o		 <= user_addr[1];
					'd25:scl		 <= 'd1;
					'd27:scl		 <= 'd0;
					'd28:sda_o		 <= user_addr[0];
					'd29:scl		 <= 'd1;
					'd31:scl		 <= 'd0;
					'd32:begin
						user_rw_done <= 'd1;
						sda_o		 <= 'd0;
					end
					'd33:scl		 <= 'd1;
					'd34:begin
						step_done 	 <= 'd1;
						if(!sda_i)begin
							iic_ack 	<= 'd1;
						end
						else begin
							iic_error	<= 'd1;
						end
					end
					'd35:begin
						scl 		 <= 'd0;
						step_cnt	 <= 'd0;
					end
				endcase
			end
			SEND_DATA:begin
				case(step_cnt)
					'd0:begin
						user_rw_done <= 'd0;
						sda_o		 <= user_wr_dat[7];
					end
					'd1:scl 		 <= 'd1;
					'd3:scl			 <= 'd0;
					'd4:sda_o		 <= user_wr_dat[6];
					'd5:scl			 <= 'd1;
					'd7:scl			 <= 'd0;
					'd8:sda_o		 <= user_wr_dat[5];
					'd9:scl			 <= 'd1;
					'd11:scl		 <= 'd0;
					'd12:sda_o		 <= user_wr_dat[4];
					'd13:scl		 <= 'd1;
					'd15:scl		 <= 'd0;
					'd16:sda_o		 <= user_wr_dat[3];
					'd17:scl		 <= 'd1;
					'd19:scl		 <= 'd0;
					'd20:sda_o		 <= user_wr_dat[2];
					'd21:scl		 <= 'd1;
					'd23:scl		 <= 'd0;
					'd24:sda_o		 <= user_wr_dat[1];
					'd25:scl		 <= 'd1;
					'd27:scl		 <= 'd0;
					'd28:sda_o		 <= user_wr_dat[0];
					'd29:scl		 <= 'd1;
					'd31:scl		 <= 'd0;
					'd32:begin
						user_rw_done <= 'd1;
						sda_o		 <= 'd0;
					end
					'd33:scl		 <= 'd1;
					'd34:begin
						step_done 	 <= 'd1;
						if(!sda_i)begin
							iic_ack 	<= 'd1;
						end
						else begin
							iic_error	<= 'd1;
						end
					end
					'd35:begin
						scl 		 <= 'd0;
						step_cnt	 <= 'd0;
					end
				endcase
			end
			END:begin
				case(step_cnt)
					'd0:begin
						user_rw_done <= 'd0;
						sda_o		 <= 'd0;
					end
					'd1:scl			 <= 'd1;
					'd3:sda_o		 <= 'd1;
					'd15:step_done	 <= 'd1;
					'd16:begin
						step_cnt 	 <= 'd0;
						iic_flash 	 <= 'd1;
					end
				endcase
			end
			SEND_READ_START:begin
				case(step_cnt)
					'd0:begin
						user_rw_done <= 'd0;
						sda_o		 <= 'd1;
					end
					'd1:scl 		 <= 'd1;
					'd2:sda_o		 <= 'd0;
					'd3:scl			 <= 'd0;
					'd4:sda_o		 <= user_slave_addr[6];
					'd5:scl			 <= 'd1;
					'd7:scl			 <= 'd0;
					'd8:sda_o		 <= user_slave_addr[5];
					'd9:scl			 <= 'd1;
					'd11:scl		 <= 'd0;
					'd12:sda_o		 <= user_slave_addr[4];
					'd13:scl		 <= 'd1;
					'd15:scl		 <= 'd0;
					'd16:sda_o		 <= user_slave_addr[3];
					'd17:scl		 <= 'd1;
					'd19:scl		 <= 'd0;
					'd20:sda_o		 <= user_slave_addr[2];
					'd21:scl		 <= 'd1;
					'd23:scl		 <= 'd0;
					'd24:sda_o		 <= user_slave_addr[1];
					'd25:scl		 <= 'd1;
					'd27:scl		 <= 'd0;
					'd28:sda_o		 <= user_slave_addr[0];
					'd29:scl		 <= 'd1;
					'd31:scl		 <= 'd0;
					'd32:sda_o		 <= 'd1;
					'd33:scl		 <= 'd1;
					'd35:scl		 <= 'd0;
					'd36:begin
						user_rw_done <= 'd1;
						sda_o		 <= 'd1;
					end
					'd37:scl		 <= 'd1;
					'd38:begin
						step_done 	 <= 'd1;
						if(!sda_i)begin
							iic_ack 	<= 'd1;
						end
						else begin
							iic_error	<= 'd1;
						end
					end
					'd39:begin
						scl 		 <= 'd0;
						step_cnt	 <= 'd0;
					end
				endcase
			end
			READ_DATA:begin
				case(step_cnt)
					'd1:begin
						iic_rd_dat[7] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd3:scl			  <= 'd0	;
					'd5:begin
						iic_rd_dat[6] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd7:scl			  <= 'd0	;
					'd9:begin
						iic_rd_dat[5] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd11:scl		  <= 'd0	;
					'd13:begin
						iic_rd_dat[4] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd15:scl		  <= 'd0	;
					'd17:begin
						iic_rd_dat[3] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd19:scl		  <= 'd0	;
					'd21:begin
						iic_rd_dat[2] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd23:scl		  <= 'd0	;
					'd25:begin
						iic_rd_dat[1] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd27:scl		  <= 'd0	;
					'd29:begin
						iic_rd_dat[0] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd31:scl		  <= 'd0	;
					'd32:begin
						user_rw_done  <= 'd0;
						sda_o		  <= 'd1;
					end
					'd33:scl		  <= 'd1;
					'd34:step_done	  <= 'd1;
					'd35:begin
						scl			  <= 'd0;
						step_cnt	  <= 'd0;
					end
				endcase
			end
			READ_DATA_6BYTES:begin
				case(step_cnt)
					'd1:begin
						iic_rd_dat_6B[47] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd3:scl			  <= 'd0	;
					'd5:begin
						iic_rd_dat_6B[46] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd7:scl			  <= 'd0	;
					'd9:begin
						iic_rd_dat_6B[45] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd11:scl		  <= 'd0	;
					'd13:begin
						iic_rd_dat_6B[44] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd15:scl		  <= 'd0	;
					'd17:begin
						iic_rd_dat_6B[43] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd19:scl		  <= 'd0	;
					'd21:begin
						iic_rd_dat_6B[42] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd23:scl		  <= 'd0	;
					'd25:begin
						iic_rd_dat_6B[41] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd27:scl		  <= 'd0	;
					'd29:begin
						iic_rd_dat_6B[40] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd31:scl		  <= 'd0	;
					'd32:begin
						user_rw_done 	<= 'd0	;
						sda_o		  	<= 'd0	;
					end
					'd33:begin
						scl			  <= 'd1	;
					end
					'd35:begin
						scl			  <= 'd0	;
					end
					'd36:begin
						user_rw_done 	<= 'd1	;
					end
					//////////////////////////////////////////
					'd37:begin
						iic_rd_dat_6B[39] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd39:scl			  <= 'd0	;
					'd41:begin
						iic_rd_dat_6B[38] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd43:scl			  <= 'd0	;
					'd45:begin
						iic_rd_dat_6B[37] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd47:scl		  <= 'd0	;
					'd49:begin
						iic_rd_dat_6B[36] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd51:scl		  <= 'd0	;
					'd53:begin
						iic_rd_dat_6B[35] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd55:scl		  <= 'd0	;
					'd57:begin
						iic_rd_dat_6B[34] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd59:scl		  <= 'd0	;
					'd61:begin
						iic_rd_dat_6B[33] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd63:scl		  <= 'd0	;
					'd65:begin
						iic_rd_dat_6B[32] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd67:scl		  <= 'd0	;
					'd68:begin
						user_rw_done 	<= 'd0	;
						sda_o		  	<= 'd0	;
					end
					'd69:begin
						scl			  <= 'd1	;
					end
					'd71:begin
						scl			  <= 'd0	;
					end
					'd72:begin
						user_rw_done 	<= 'd1	;
					end
					//////////////////////////////////////////////
					'd73:begin
						iic_rd_dat_6B[31] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd75:scl			  <= 'd0	;
					'd77:begin
						iic_rd_dat_6B[30] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd79:scl			  <= 'd0	;
					'd81:begin
						iic_rd_dat_6B[29] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd83:scl		  <= 'd0	;
					'd85:begin
						iic_rd_dat_6B[28] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd87:scl		  <= 'd0	;
					'd89:begin
						iic_rd_dat_6B[27] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd91:scl		  <= 'd0	;
					'd93:begin
						iic_rd_dat_6B[26] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd95:scl		  <= 'd0	;
					'd97:begin
						iic_rd_dat_6B[25] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd99:scl		  <= 'd0	;
					'd101:begin
						iic_rd_dat_6B[24] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd103:scl		  <= 'd0	;
					'd104:begin
						user_rw_done 	<= 'd0	;
						sda_o		  	<= 'd0	;
					end
					'd105:begin
						scl			  <= 'd1	;
					end
					'd107:begin
						scl			  <= 'd0	;
					end
					'd108:begin
						user_rw_done 	<= 'd1	;
					end
					//////////////////////////////////////
					'd109:begin
						iic_rd_dat_6B[23] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd111:scl			  <= 'd0	;
					'd113:begin
						iic_rd_dat_6B[22] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd115:scl			  <= 'd0	;
					'd117:begin
						iic_rd_dat_6B[21] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd119:scl		  <= 'd0	;
					'd121:begin
						iic_rd_dat_6B[20] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd123:scl		  <= 'd0	;
					'd125:begin
						iic_rd_dat_6B[19] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd127:scl		  <= 'd0	;
					'd129:begin
						iic_rd_dat_6B[18] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd131:scl		  <= 'd0	;
					'd133:begin
						iic_rd_dat_6B[17] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd135:scl		  <= 'd0	;
					'd137:begin
						iic_rd_dat_6B[16] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd139:scl		  <= 'd0	;
					'd140:begin
						user_rw_done 	<= 'd0	;
						sda_o		  	<= 'd0	;
					end
					'd141:begin
						scl			  <= 'd1	;
					end
					'd143:begin
						scl			  <= 'd0	;
					end
					'd144:begin
						user_rw_done 	<= 'd1	;
					end
					//////////////////////////////////////////
					'd145:begin
						iic_rd_dat_6B[15] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd147:scl			  <= 'd0	;
					'd149:begin
						iic_rd_dat_6B[14] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd151:scl			  <= 'd0	;
					'd153:begin
						iic_rd_dat_6B[13] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd155:scl		  <= 'd0	;
					'd157:begin
						iic_rd_dat_6B[12] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd159:scl		  <= 'd0	;
					'd161:begin
						iic_rd_dat_6B[11] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd163:scl		  <= 'd0	;
					'd165:begin
						iic_rd_dat_6B[10] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd167:scl		  <= 'd0	;
					'd169:begin
						iic_rd_dat_6B[9] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd171:scl		  <= 'd0	;
					'd173:begin
						iic_rd_dat_6B[8] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd175:scl		  <= 'd0	;
					'd176:begin
						user_rw_done 	<= 'd0	;
						sda_o		  	<= 'd0	;
					end
					'd177:begin
						scl			  <= 'd1	;
					end
					'd179:begin
						scl			  <= 'd0	;
					end
					'd180:begin
						user_rw_done 	<= 'd1	;
					end

					//////////////////////////////////////////////
					'd181:begin
						iic_rd_dat_6B[7] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd183:scl			  <= 'd0	;
					'd185:begin
						iic_rd_dat_6B[6] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd187:scl			  <= 'd0	;
					'd189:begin
						iic_rd_dat_6B[5] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd191:scl		  <= 'd0	;
					'd193:begin
						iic_rd_dat_6B[4] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd195:scl		  <= 'd0	;
					'd197:begin
						iic_rd_dat_6B[3] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd199:scl		  <= 'd0	;
					'd201:begin
						iic_rd_dat_6B[2] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd203:scl		  <= 'd0	;
					'd205:begin
						iic_rd_dat_6B[1] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd207:scl		  <= 'd0	;
					'd209:begin
						iic_rd_dat_6B[0] <= sda_i	;
						scl			  <= 'd1	;
					end
					'd211:scl		  <= 'd0	;
					'd212:begin
						user_rw_done  <= 'd0;
						sda_o		  <= 'd0;
					end
					'd213:scl		  <= 'd1;
					'd214:step_done	  <= 'd1;
					'd215:begin
						scl			  <= 'd0;
						step_cnt	  <= 'd0;
					end
				endcase
			end
			default:begin
				step_cnt		<= 'd0;//步进计数
				step_done		<= 'd0;//每一步完成信�?
				iic_ack			<= 'd0;//iic应答信号
				scl				<= 'd1;//时钟线拉�?
				user_rw_done	<= 'd0;//表示数据输出
				sda_o			<= 'd1;//数据拉高
				iic_rd_dat		<= iic_rd_dat;//读取的数�?
				iic_rd_dat_6B	<= iic_rd_dat_6B;//读出数据
			end
		endcase
	end
end

// ila_0 u_ila_128x1024 (
	// .clk(iic_user_clk), // input wire clk
	// .probe0({
			// scl,
			// sda_i,
			// sda_o,
			// sda,
			// user_rw_done,
			// iic_ack,
			// state,
			// next_state,
			// step_done,
			// iic_rd_dat_6B,
			// step_cnt,
			// iic_error
	// }) // input wire [127:0] probe0
// );


endmodule
