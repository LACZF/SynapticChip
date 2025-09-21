// tb_pe_controller.v
// PE控制器测试平台

`include "pe_ctrl_params.v"
`timescale 1ns/1ps

module tb_pe_controller;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // Ring总线接口
    reg ring_in_valid;
    reg [`NODE_ID_WIDTH-1:0] ring_in_src;
    reg [`NODE_ID_WIDTH-1:0] ring_in_dest;
    reg [`ADDR_WIDTH-1:0] ring_in_addr;
    reg [`DATA_WIDTH-1:0] ring_in_data;
    reg ring_in_we;
    reg [3:0] ring_in_be;
    reg ring_in_ack;

    wire ring_out_valid;
    wire [`NODE_ID_WIDTH-1:0] ring_out_src;
    wire [`NODE_ID_WIDTH-1:0] ring_out_dest;
    wire [`ADDR_WIDTH-1:0] ring_out_addr;
    wire [`DATA_WIDTH-1:0] ring_out_data;
    wire ring_out_we;
    wire [3:0] ring_out_be;
    wire ring_out_ack;

    // PE控制信号
    wire [`NUM_PES-1:0] pe_enable;
    wire [`NUM_PES-1:0] pe_reset;
    wire [(`NUM_PES*`INST_WIDTH)-1:0] pe_instructions;
    wire pe_inst_valid;

    // PE状态
    reg [(`NUM_PES*`DATA_WIDTH)-1:0] pe_status;
    reg [(`NUM_PES*`DATA_WIDTH)-1:0] pe_outputs;
    reg [`NUM_PES-1:0] pe_busy;

    // 路由配置
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] route_config;
    wire route_cfg_valid;

    // 实例化DUT
    pe_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .ring_in_valid(ring_in_valid),
        .ring_in_src(ring_in_src),
        .ring_in_dest(ring_in_dest),
        .ring_in_addr(ring_in_addr),
        .ring_in_data(ring_in_data),
        .ring_in_we(ring_in_we),
        .ring_in_be(ring_in_be),
        .ring_in_ack(ring_in_ack),
        .ring_out_valid(ring_out_valid),
        .ring_out_src(ring_out_src),
        .ring_out_dest(ring_out_dest),
        .ring_out_addr(ring_out_addr),
        .ring_out_data(ring_out_data),
        .ring_out_we(ring_out_we),
        .ring_out_be(ring_out_be),
        .ring_out_ack(ring_out_ack),
        .pe_enable(pe_enable),
        .pe_reset(pe_reset),
        .pe_instructions(pe_instructions),
        .pe_inst_valid(pe_inst_valid),
        .pe_status(pe_status),
        .pe_outputs(pe_outputs),
        .pe_busy(pe_busy),
        .route_config(route_config),
        .route_cfg_valid(route_cfg_valid)
    );

    // 实例化路由配置模块
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] north_routes;
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] south_routes;
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] east_routes;
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] west_routes;

    route_config route_cfg (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(route_cfg_valid),
        .cfg_data(route_config),
        .north_routes(north_routes),
        .south_routes(south_routes),
        .east_routes(east_routes),
        .west_routes(west_routes)
    );

    // 实例化PE阵列
    genvar i;
    generate
        for (i = 0; i < `NUM_PES; i = i + 1) begin : pe_array
            simple_pe pe (
                .clk(clk),
                .rst_n(rst_n & !pe_reset[i]),
                .enable(pe_enable[i]),
                .instruction(pe_instructions[i*`INST_WIDTH +: `INST_WIDTH]),
                .inst_valid(pe_inst_valid),
                .north_valid(1'b0),
                .north_data(0),
                .north_ready(),
                .south_valid(1'b0),
                .south_data(0),
                .south_ready(),
                .east_valid(1'b0),
                .east_data(0),
                .east_ready(),
                .west_valid(1'b0),
                .west_data(0),
                .west_ready(),
                .north_route(north_routes[i*4*`PE_ID_WIDTH +: `PE_ID_WIDTH]),
                .south_route(south_routes[i*4*`PE_ID_WIDTH +: `PE_ID_WIDTH]),
                .east_route(east_routes[i*4*`PE_ID_WIDTH +: `PE_ID_WIDTH]),
                .west_route(west_routes[i*4*`PE_ID_WIDTH +: `PE_ID_WIDTH]),
                .data_out(pe_outputs[i*`DATA_WIDTH +: `DATA_WIDTH]),
                .out_valid(),
                .busy(pe_busy[i]),
                .status(pe_status[i*`DATA_WIDTH +: `DATA_WIDTH])
            );
        end
    endgenerate

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：发送写请求
    task send_write;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        input [3:0] be;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 0;  // 控制器节点ID
            ring_in_addr <= addr;
            ring_in_data <= data;
            ring_in_we <= 1'b1;
            ring_in_be <= be;

            // 等待确认
            wait(ring_out_ack);
            @(posedge clk);
            ring_in_valid <= 1'b0;
            ring_in_we <= 1'b0;
        end
    endtask

    // 测试任务：发送读请求
    task send_read;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        output [`DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 0;  // 控制器节点ID
            ring_in_addr <= addr;
            ring_in_we <= 1'b0;
            ring_in_be <= 4'b1111;

            // 等待回复
            wait(ring_out_valid && ring_out_dest == src && !ring_out_we);
            data = ring_out_data;
            @(posedge clk);
            ring_in_valid <= 1'b0;
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] read_data;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ring_in_valid = 0;
        ring_in_src = 0;
        ring_in_dest = 0;
        ring_in_addr = 0;
        ring_in_data = 0;
        ring_in_we = 0;
        ring_in_be = 0;
        ring_in_ack = 0;
        pe_status = 0;
        pe_outputs = 0;
        pe_busy = 0;

        // 复位
        #20 rst_n = 1;

        $display("Starting PE Controller Test");

        // 测试1: 配置PE使能和复位
        $display("Test 1: Configure PE enable and reset");
        send_write(1, `REG_PE_CTRL, 32'h0000FFFF, 4'b1111); // 低16位使能，高16位复位
        #100;

        // 检查PE使能信号
        if (pe_enable !== 16'hFFFF) begin
            $display("ERROR: PE enable signals incorrect: 0x%h", pe_enable);
            $finish;
        end else begin
            $display("PASS: PE enable signals correct: 0x%h", pe_enable);
        end

        // 测试2: 发送指令到PE
        $display("Test 2: Send instruction to PE");
        send_write(1, `REG_PE_INST, 32'h12345678, 4'b1111); // 发送测试指令
        #100;

        // 检查指令是否广播到所有PE
        for (integer i = 0; i < `NUM_PES; i = i + 1) begin
            if (pe_instructions[i*`INST_WIDTH +: `INST_WIDTH] !== 32'h12345678) begin
                $display("ERROR: PE %d instruction incorrect: 0x%h", i,
                         pe_instructions[i*`INST_WIDTH +: `INST_WIDTH]);
                $finish;
            end
        end
        $display("PASS: Instructions correctly broadcast to all PEs");

        // 测试3: 配置路由
        $display("Test 3: Configure routing");
        send_write(1, `REG_ROUTE_CFG, 32'h01234567, 4'b1111); // 发送路由配置
        #100;

        // 检查路由配置是否有效
        if (!route_cfg_valid) begin
            $display("ERROR: Route configuration not valid");
            $finish;
        end else begin
            $display("PASS: Route configuration valid");
        end

        // 测试4: 读取PE状态
        $display("Test 4: Read PE status");

        // 设置一些测试状态
        pe_outputs[15:0] = 16'hABCD;
        pe_busy[0] = 1'b1;

        send_read(1, `REG_PE_STAT, read_data);
        $display("PE status: 0x%h", read_data);

        // 测试5: 读取PE数据
        $display("Test 5: Read PE data");
        send_read(1, `REG_PE_DATA, read_data);
        if (read_data !== 16'hABCD) begin
            $display("ERROR: PE data read 0x%h, expected 0xABCD", read_data);
            $finish;
        end else begin
            $display("PASS: PE data correctly read: 0x%h", read_data);
        end

        // 测试6: 禁用部分PE
        $display("Test 6: Disable some PEs");
        send_write(1, `REG_PE_CTRL, 32'h0000000F, 4'b1111); // 只使能前4个PE
        #100;

        if (pe_enable !== 16'h000F) begin
            $display("ERROR: PE enable signals incorrect after disable: 0x%h", pe_enable);
            $finish;
        end else begin
            $display("PASS: PE enable signals correctly updated: 0x%h", pe_enable);
        end

        $display("All tests passed!");
        $finish;
    end

    // 模拟Ring总线的确认信号
    always @(posedge clk) begin
        if (ring_out_valid && ring_out_dest == 1) begin
            // 如果是发给节点1的回复，模拟确认
            ring_in_ack <= 1'b1;
        end else begin
            ring_in_ack <= 1'b0;
        end
    end

    // 波形输出
    initial begin
        $dumpfile("pe_controller.vcd");
        $dumpvars(0, tb_pe_controller);
    end

endmodule
