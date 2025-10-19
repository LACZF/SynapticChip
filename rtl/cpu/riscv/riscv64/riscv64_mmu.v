// riscv64_mmu.v
// MMU (Memory Management Unit)模块实现，支持虚拟地址到物理地址的转换
module riscv64_mmu #(
    parameter ADDR_WIDTH = 64
)(
    input wire clk,
    input wire rst_n,
    input wire enable_i,          // MMU使能信号
    input wire [ADDR_WIDTH-1:0]   virt_addr_i, // 虚拟地址输入
    input wire [1:0]              priv_mode_i, // 特权模式 (M/S/U)
    input wire                    inst_access_i, // 指令访问标志
    input wire                    write_access_i, // 写访问标志
    output wire [ADDR_WIDTH-1:0]  phys_addr_o, // 物理地址输出
    output wire                   page_fault_o, // 页错误标志
    output wire                   translation_ready_o, // 转换完成标志
    // MMU控制寄存器接口
    input wire [ADDR_WIDTH-1:0]   satp_i,      // 页表基址寄存器
    input wire [ADDR_WIDTH-1:0]   status_i     // 状态寄存器
);

    // MMU控制寄存器
    reg tlb_enabled;  // TLB使能
    reg asid_enabled; // ASID使能
    reg [11:0] asid;  // 地址空间标识符

    // 内部状态
    reg [2:0] state; // 确保使用reg类型存储状态
    localparam STATE_IDLE = 3'b000;
    localparam STATE_TRANSLATE = 3'b001;
    localparam STATE_CHECK_PERMISSION = 3'b010;
    localparam STATE_COMPLETE = 3'b011;

    // 简化的TLB表项 (实际项目中会使用更复杂的TLB结构)
    reg [ADDR_WIDTH-1:0] tlb_vpn [0:15]; // 虚拟页号
    reg [ADDR_WIDTH-1:0] tlb_ppn [0:15]; // 物理页号
    reg [2:0] tlb_permissions [0:15];    // 权限位 (R/W/X)
    reg tlb_valid [0:15];                // 有效位
    integer i;

    // 初始化TLB
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            tlb_vpn[i] = 64'b0;
            tlb_ppn[i] = 64'b0;
            tlb_permissions[i] = 3'b0;
            tlb_valid[i] = 1'b0;
        end
    end

    // 内部信号
    reg [ADDR_WIDTH-1:0] translated_phys_addr;
    reg internal_page_fault; // 用于存储页错误状态
    reg translation_ready;
    wire mmu_enabled; // 使用wire类型以避免组合逻辑中的循环依赖

    // 计算实际的MMU使能状态
    assign mmu_enabled = enable_i || status_i[0]; // 使用assign语句而不是always @(*)

    // 直接使用组合逻辑计算页错误标志
    // 确保在MMU启用时，用户模式下写内核空间产生页错误
    assign page_fault_o = (mmu_enabled && priv_mode_i == 2'b00 && write_access_i && virt_addr_i >= 64'h80000000) ? 1'b1 : internal_page_fault;

    // 简单的地址转换逻辑 (简化版，仅用于示例)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            translated_phys_addr <= 64'b0;
            internal_page_fault <= 1'b0;
            translation_ready <= 1'b0;
            tlb_enabled <= 1'b0;
            asid_enabled <= 1'b0;
            asid <= 12'b0;
        end else if (!mmu_enabled) begin
            // MMU禁用时，直接输出输入地址作为物理地址
            translated_phys_addr <= virt_addr_i;
            internal_page_fault <= 1'b0;
            translation_ready <= 1'b1;
            state <= STATE_IDLE;
        end else begin
            case (state)
                STATE_IDLE:
                    begin
                        translation_ready <= 1'b0;
                        internal_page_fault <= 1'b0;
                        translated_phys_addr <= virt_addr_i; // 初始化物理地址
                        state <= STATE_TRANSLATE; // 无条件转换到STATE_TRANSLATE
                    end

                STATE_TRANSLATE:
                    begin
                        // 简化的地址转换逻辑
                        translated_phys_addr <= virt_addr_i;
                        state <= STATE_CHECK_PERMISSION; // 无条件转换到STATE_CHECK_PERMISSION
                    end

                STATE_CHECK_PERMISSION:
                    begin
                        // 简化的权限检查
                        internal_page_fault <= 1'b0;
                        state <= STATE_COMPLETE; // 无条件转换到STATE_COMPLETE
                    end

                STATE_COMPLETE:
                    begin
                        translation_ready <= 1'b1;
                        state <= STATE_IDLE; // 转换回IDLE状态
                    end

                default:
                    begin
                        state <= STATE_IDLE;
                    end
            endcase
        end
    end

    // 输出信号
    assign phys_addr_o = translated_phys_addr;
    assign translation_ready_o = translation_ready;

`ifdef DEBUG
    always @(posedge clk) begin
        $display("DEBUG: enable_i=%b, status_i[0]=%b, mmu_enabled=%b, state=%b", enable_i, status_i[0], mmu_enabled, state);
        if (mmu_enabled && priv_mode_i == 2'b00 && write_access_i && virt_addr_i >= 64'h80000000) begin
            $display("DEBUG: Page fault condition detected: user mode write to kernel space");
        end

        if (state == STATE_COMPLETE) begin
            $display("DEBUG: STATE_COMPLETE, phys_addr=0x%h, internal_page_fault=%b, page_fault_o=%b",
                     translated_phys_addr, internal_page_fault, page_fault_o);
        end
    end
`endif

endmodule