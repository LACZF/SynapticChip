module apb_ram #(
    parameter MEM_SIZE = 1024,        // 内存大小（字节）
    parameter ADDR_WIDTH = 10,        // 地址宽度
    parameter INIT_FILE = "none"      // 初始化文件路径，"none"表示不初始化
)(
    // APB接口信号
    input  wire        clk,
    input  wire        rst_n,
    input  wire        apb_psel_i,
    input  wire        apb_penable_i,
    input  wire [31:0] apb_paddr_i,
    input  wire        apb_pwrite_i,
    input  wire [31:0] apb_pwdata_i,
    output reg         apb_pready_o,
    output reg  [31:0] apb_prdata_o,
    output reg         apb_pslverr_o
);

    // 内存数组 - 按字（32位）组织，简化字节序处理
    reg [31:0] memory [0:(MEM_SIZE/4)-1];

    // 内部信号
    reg ready_reg;
    reg [31:0] read_data_reg;
    reg error_reg;

    // 地址对齐检查 - 确保地址是4字节对齐的
    wire addr_valid = (apb_paddr_i[1:0] == 2'b00) && (apb_paddr_i < MEM_SIZE);
    wire [ADDR_WIDTH-3:0] word_addr = apb_paddr_i[ADDR_WIDTH-1:2]; // 字地址

    // APB传输处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_reg <= 1'b0;
            read_data_reg <= 32'b0;
            error_reg <= 1'b0;
        end else begin
            // 默认值
            ready_reg <= 1'b0;
            error_reg <= 1'b0;

            // APB传输检测
            if (apb_psel_i && apb_penable_i && !ready_reg) begin
                ready_reg <= 1'b1;

                if (addr_valid) begin
                    if (apb_pwrite_i) begin
                        // 写操作 - 直接存储32位字
                        memory[word_addr] <= apb_pwdata_i;
                        read_data_reg <= 32'b0;
                    `ifdef DEBUG
                        $display("APB RAM Write: Word_Addr=0x%h, Data=0x%h",
                                 word_addr, apb_pwdata_i);
                    `endif
                    end else begin
                        // 读操作 - 直接读取32位字
                        read_data_reg <= memory[word_addr];

                    `ifdef DEBUG
                        $display("APB RAM Read: Word_Addr=0x%h, Data=0x%h",
                                 word_addr, read_data_reg);
                    `endif
                    end
                end else begin
                    // 地址错误
                    error_reg <= 1'b1;
                    read_data_reg <= 32'hDEADBEEF;  // 错误模式值
                    $display("APB RAM Error: Invalid address 0x%h", apb_paddr_i);
                end
            end
        end
    end

    // 输出赋值
    always @(*) begin
        apb_pready_o = ready_reg;
        apb_prdata_o = read_data_reg;
        apb_pslverr_o = error_reg;
    end

    // 内存初始化
    integer i;
    initial begin
        // 默认初始化为零
        for (i = 0; i < MEM_SIZE/4; i = i + 1) begin
            memory[i] = 32'h00000000;
        end

        // 如果指定了初始化文件，则从文件加载
        if (INIT_FILE != "none") begin
        `ifdef DEBUG
            $display("Initializing APB RAM from file: %s", INIT_FILE);
        `endif
            // 使用$readmemh直接加载32位字
            $readmemh(INIT_FILE, memory);
        `ifdef DEBUG
            $display("APB RAM initialization completed");
        `endif
        end else begin
        `ifdef DEBUG
            $display("APB RAM initialized with zeros");
        `endif
        end

        `ifdef DEBUG
            // 打印前几个内存位置的内容用于调试
            $display("First 4 words of APB RAM:");
            for (i = 0; i < 4; i = i + 1) begin
                $display("memory[%0d] = 0x%h", i, memory[i]);
            end
        `endif
    end

endmodule