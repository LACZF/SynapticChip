`timescale 1ns/1ps

`define CMD_WRITE_DISABLE 			      		8'h04
`define CMD_WRITE_ENABLE  			      		8'h06
`define CMD_READ_STATUS				        	8'h05
`define CMD_WRITE_STATUS				       	8'h01
`define CMD_READ_STATUS2				       	8'h35
`define CMD_WRITE_STATUS2          				8'h31
`define CMD_READ_STATUS3           				8'h15
`define CMD_WRITE_STATUS3          				8'h11
`define CMD_READ_DATA				          	8'h03
`define CMD_READ_DATA_FAST			      		8'h0B
`define CMD_READ_DATA_FAST_WRAP    				8'h0C
`define CMD_READ_DATA_FAST_DTR    				8'h0D
`define CMD_READ_DATA_FAST_DTR_WRAP    				8'h0E
`define CMD_READ_DATA_FAST_DUAL		  			8'h3B
`define CMD_READ_DATA_FAST_DUAL_IO				8'hBB
`define CMD_READ_DATA_FAST_DUAL_IO_DTR				8'hBD
`define CMD_READ_DATA_FAST_QUAD		  			8'h6B
`define CMD_READ_DATA_FAST_QUAD_IO				8'hEB
`define CMD_READ_DATA_FAST_QUAD_IO_DTR				8'hED
`define CMD_PAGE_PROGRAM				       	8'h02
`define CMD_PAGE_PROGRAM_QUAD			   		8'h32
`define CMD_BLOCK_ERASE				        	8'hD8
`define CMD_HALF_BLOCK_ERASE			    		8'h52
`define CMD_SECTOR_ERASE				       	8'h20
`define CMD_BULK_ERASE				         	8'hC7
`define CMD_BULK_ERASE2				        	8'h60
`define CMD_DEEP_POWERDOWN			      		8'hB9
`define CMD_READ_SIGNATURE			      		8'hAB
`define CMD_READ_ID					        8'h90
`define CMD_READ_ID_DUAL           				8'h92
`define CMD_READ_ID_QUAD           				8'h94
`define CMD_READ_JEDEC_ID			       		8'h9F
`define CMD_READ_UNIQUE_ID			      		8'h4B
`define CMD_SUSPEND                				8'h75
`define CMD_RESUME                 				8'h7A
`define CMD_SET_BURST_WRAP         				8'h77
`define CMD_MODE_RESET             				8'hFF
`define CMD_DISABLE_QPI            				8'hFF
`define CMD_ENABLE_QPI             				8'h38
`define CMD_ENABLE_RESET           				8'h66
`define CMD_CHIP_RESET             				8'h99
`define CMD_SET_READ_PARAM         				8'hC0
`define CMD_SREG_PROGRAM           				8'h42
`define CMD_SREG_ERASE             				8'h44
`define CMD_SREG_READ              				8'h48
`define CMD_WRITE_ENABLE_VSR       				8'h50
`define CMD_READ_SFDP              				8'h5A
`define CMD_INDIVIDUAL_LOCK        				8'h36
`define CMD_INDIVIDUAL_UNLOCK      				8'h39
`define CMD_READ_BLOCK_LOCK        				8'h3D
`define CMD_GLOBAL_BLOCK_LOCK      				8'h7E
`define CMD_GLOBAL_BLOCK_UNLOCK    				8'h98

module tb_spi_flash_master;
    // 时钟和复位
    reg         clk;
    reg         rst_n;

    // OBI总线接口
    reg         req_i;
    wire        gnt_o;
    wire        rvalid_o;
    reg  [31:0] addr_i;
    reg         we_i;
    reg  [3:0]  be_i;
    reg  [31:0] wdata_i;
    wire [31:0] rdata_o;

    // SPI接口
    wire        spi_cs_n;
    wire        spi_sck;
    wire        spi_mosi;
    wire        spi_miso;

    // 时钟生成
    always #5 clk = ~clk;  // 100MHz时钟

    reg        enable;            // enable the master to start operation
    reg [31:0] data_out;      // Data to be sent
    reg [7:0]  commands;     // commad to be sent
    reg [23:0] Address;      // Adddress to be sent

    SPI_Master uut_master (
        .clk(clk),
        .rst(!rst_n),
        .enable(enable),
        .data_out(data_out),
        .commands(commands),
        .Address(Address),
        .CS(spi_cs_n),
        .SCLK(spi_sck),
        .MOSI(spi_mosi),
        .MISO(spi_miso)
    );

    // 声明Flash模型的控制信号
    wire flash_wpn;
    wire flash_holdn;

    // 实例化W25Q128JVxIM Flash模型
    W25Q128JVxIM u_flash (
        .CSn(spi_cs_n),
        .CLK(spi_sck),
        .DIO(spi_mosi),       // 标准SPI模式：DIO作为MOSI输入
        .DO(spi_miso),        // 标准SPI模式：DO作为MISO输出
        .WPn(flash_wpn),      // 写保护
        .HOLDn(flash_holdn)   // 保持
    );

    // 连接Flash模型的控制信号
    assign flash_wpn   = 1'b1;    // 写保护禁用
    assign flash_holdn = 1'b1;  // 保持禁用

    initial begin
        clk      <= 0;
        rst_n    <= 0;

        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
        rst_n <= 1;

        #100;
        data_out = 0;
        commands = `CMD_READ_STATUS;
        Address  = 0;
        enable   = 1;
        @(posedge clk);
        enable   = 0;

        #100;
        data_out = 0;
        commands = `CMD_READ_DATA;
        Address  = 0;
        enable   = 1;
        @(posedge clk);
        enable   = 0;

        # 5000;
        $finish;
    end

    // 仿真超时保护
    initial begin
        #50000000;  // 50ms超时
        $display("仿真超时！");
        $finish;
    end

    initial begin
        $dumpfile("tb_spi_flash_master.vcd");
        $dumpvars(0, tb_spi_flash_master);
    end

endmodule