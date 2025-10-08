// PE_TOP测试平台

`include "top_system_params.v"
`include "pe_ctrl_params.v"
`timescale 1ns/1ps

module tb_pe_top;
    localparam INST_WIDTH = 32;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 直接控制接口
    reg [`NUM_PES-1:0] pe_enable;
    reg [`NUM_PES-1:0] pe_reset;
    reg [(`NUM_PES*INST_WIDTH)-1:0] pe_instructions;
    reg pe_inst_valid;
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] route_config; // 路由配置
    reg route_cfg_valid;

    // 状态输出
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_status;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_outputs;
    wire [`NUM_PES-1:0] pe_busy;
    wire [`DATA_WIDTH-1:0] fabric_status;

    // 实例化DUT
    pe_top #(
        .NUM_PES(`NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(`ADDR_WIDTH),
        .PE_ID_WIDTH(`PE_ID_WIDTH),
        .PE_ARRAY_ROWS(`PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(`PE_ARRAY_COLS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pe_enable(pe_enable),
        .pe_reset(pe_reset),
        .pe_instructions(pe_instructions),
        .pe_inst_valid(pe_inst_valid),
        .route_config(route_config),
        .route_cfg_valid(route_cfg_valid),
        .pe_status(pe_status),
        .pe_outputs(pe_outputs),
        .pe_busy(pe_busy),
        .fabric_status(fabric_status)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：控制PE使能
    task control_pe_enable;
        input [`NUM_PES-1:0] enable_mask;
        begin
            @(posedge clk);
            pe_enable <= enable_mask;
            @(posedge clk);
        end
    endtask

    // 测试任务：控制PE复位
    task control_pe_reset;
        input [`NUM_PES-1:0] reset_mask;
        input integer reset_cycles;
        integer i;
        begin
            @(posedge clk);
            pe_reset <= reset_mask;
            for (i = 0; i < reset_cycles; i = i + 1) begin
                @(posedge clk);
            end
            pe_reset <= 0;
        end
    endtask

    // 测试任务：配置PE指令
    task configure_pe_instruction;
        input integer pe_id;
        input [127:0] instruction;
        begin
            @(posedge clk);
            pe_instructions[pe_id*128 +: 128] <= instruction;
            pe_inst_valid <= 1'b1;
            @(posedge clk);
            pe_inst_valid <= 1'b0;
        end
    endtask

    // 测试任务：配置路由
    task configure_routing;
        input [(4*4*`PE_ID_WIDTH)-1:0] config_data;
        begin
            @(posedge clk);
            route_config <= config_data;
            route_cfg_valid <= 1'b1;
            @(posedge clk);
            route_cfg_valid <= 1'b0;
        end
    endtask

    // 主测试程序
    reg [127:0] test_instruction;
    integer error_count;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        pe_enable = 0;
        pe_reset = 0;
        pe_instructions = 0;
        pe_inst_valid = 0;
        route_config = 0;
        route_cfg_valid = 0;
        error_count = 0;

        // 复位
        #100 rst_n = 1;
        #200; // 给足够的时间让系统稳定

        $display("Starting PE_TOP Test");

        // 测试1: 读取初始状态
        $display("Test 1: Read initial fabric status");
        $display("Initial fabric status: 0x%h", fabric_status);
        #20;

        // 测试2: 对每个PE进行复位
        $display("Test 2: Reset all PEs");
        control_pe_reset(4'b1111, 5); // 复位所有4个PE，持续5个时钟周期
        #20;

        // 测试3: 使能所有PE
        $display("Test 3: Enable all PEs");
        control_pe_enable(4'b1111); // 使能所有4个PE
        #100; // 等待PE稳定

        // 检查PE使能状态
        if (fabric_status[3:0] != 4'b1111) begin
            $display("ERROR: PE enable status mismatch! Expected 0xF, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status verified successfully");
        end
        #20;

        // 测试4: 配置PE指令
        $display("Test 4: Configure PE instructions");
        test_instruction = 128'h00010002000300040005000600070008; // 测试指令
        configure_pe_instruction(0, test_instruction);
        configure_pe_instruction(1, test_instruction);
        configure_pe_instruction(2, test_instruction);
        configure_pe_instruction(3, test_instruction);
        #20;

        // 测试5: 配置路由
        $display("Test 5: Configure routing");
        // 简单路由配置: 每个PE的四个方向都指向自己
        configure_routing({
            {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, // PE0
            {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, // PE1
            {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, // PE2
            {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}  // PE3
        });
        #20;

        // 测试6: 观察PE状态
        $display("Test 6: Observe PE status");
        $display("PE 0 status: 0x%h", pe_status[0*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 1 status: 0x%h", pe_status[1*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 2 status: 0x%h", pe_status[2*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 3 status: 0x%h", pe_status[3*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE busy signals: 0b%b", pe_busy);
        $display("Fabric status: 0x%h", fabric_status);
        #20;

        // 测试7: 禁用部分PE
        $display("Test 7: Disable some PEs");
        control_pe_enable(4'b1010); // 禁用PE0和PE2
        #100;

        // 检查PE使能状态
        if (fabric_status[3:0] != 4'b1010) begin
            $display("ERROR: PE enable status after disable mismatch! Expected 0xA, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status after disable verified successfully");
        end
        #20;

        // 测试8: 完全禁用所有PE
        $display("Test 8: Disable all PEs");
        control_pe_enable(4'b0000); // 禁用所有PE
        #100;

        // 检查PE使能状态
        if (fabric_status[3:0] != 4'b0000) begin
            $display("ERROR: PE enable status after full disable mismatch! Expected 0x0, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status after full disable verified successfully");
        end

        // 最终测试结果
        if (error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $display("\nTEST FAILED with %0d errors", error_count);
        end

        $display("All tests completed!");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("pe_top.vcd");
        $dumpvars(0, tb_pe_top);
    end

endmodule