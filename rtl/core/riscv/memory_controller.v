// memory_controller.v
module memory_controller (
    input wire clk,
    input wire rst_n,

    // CPU指令接口
    input wire [31:0] imem_addr,
    output reg [31:0] imem_data,
    input wire imem_req,
    output reg imem_ack,

    // CPU数据接口
    input wire [31:0] dmem_addr,
    input wire [31:0] dmem_data_out,
    output reg [31:0] dmem_data_in,
    input wire dmem_we,
    input wire [3:0] dmem_sel,
    input wire dmem_req,
    output reg dmem_ack,

    // RAM接口
    output reg [31:0] ram_addr,
    output reg [31:0] ram_data_out,
    input wire [31:0] ram_data_in,
    output reg ram_we,
    output reg [3:0] ram_sel,
    output reg ram_req,
    input wire ram_ack,

    // ROM接口
    output reg [31:0] rom_addr,
    input wire [31:0] rom_data,
    output reg rom_req,
    input wire rom_ack,

    // Flash接口
    output reg [31:0] flash_addr,
    input wire [31:0] flash_data,
    output reg flash_req,
    input wire flash_ack,
    output reg flash_we,
    output reg [31:0] flash_data_out,

    // 状态输出
    output reg [2:0] mem_state
);

    // 存储器地址映射
    localparam RAM_BASE   = 32'h0000_0000;
    localparam RAM_SIZE   = 32'h0001_0000;  // 64KB
    localparam ROM_BASE   = 32'h1000_0000;
    localparam ROM_SIZE   = 32'h0010_0000;  // 1MB
    localparam FLASH_BASE = 32'h2000_0000;
    localparam FLASH_SIZE = 32'h0100_0000;  // 16MB

    // 状态定义
    localparam STATE_IDLE     = 3'b000;
    localparam STATE_RAM_READ = 3'b001;
    localparam STATE_ROM_READ = 3'b010;
    localparam STATE_FLASH_READ = 3'b011;
    localparam STATE_RAM_WRITE = 3'b100;
    localparam STATE_FLASH_WRITE = 3'b101;

    // 内部信号
    reg [31:0] current_addr;
    reg [31:0] write_data;
    reg [3:0] write_sel;
    reg is_write;
    reg imem_pending;
    reg dmem_pending;

    // 地址解码
    wire in_ram_range = (imem_addr >= RAM_BASE) && (imem_addr < RAM_BASE + RAM_SIZE);
    wire in_rom_range = (imem_addr >= ROM_BASE) && (imem_addr < ROM_BASE + ROM_SIZE);
    wire in_flash_range = (imem_addr >= FLASH_BASE) && (imem_addr < FLASH_BASE + FLASH_SIZE);

    // 指令缓存（简化）
    reg [31:0] icache_addr [0:7];
    reg [31:0] icache_data [0:7];
    reg icache_valid [0:7];
    reg [2:0] icache_index;

    integer i;

    // 初始化缓存
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            icache_valid[i] = 1'b0;
        end
    end

    // 缓存查找
    reg cache_hit;
    reg [31:0] cache_data;
    reg [2:0] hit_index;

    always @(*) begin
        cache_hit = 1'b0;
        cache_data = 32'h0;
        hit_index = 3'h0;

        for (i = 0; i < 8; i = i + 1) begin
            if (icache_valid[i] && (icache_addr[i] == imem_addr)) begin
                cache_hit = 1'b1;
                cache_data = icache_data[i];
                hit_index = i;
            end
        end
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_state <= STATE_IDLE;
            imem_data <= 32'h0;
            imem_ack <= 1'b0;
            dmem_data_in <= 32'h0;
            dmem_ack <= 1'b0;
            ram_addr <= 32'h0;
            ram_data_out <= 32'h0;
            ram_we <= 1'b0;
            ram_sel <= 4'h0;
            ram_req <= 1'b0;
            rom_addr <= 32'h0;
            rom_req <= 1'b0;
            flash_addr <= 32'h0;
            flash_req <= 1'b0;
            flash_we <= 1'b0;
            flash_data_out <= 32'h0;
            imem_pending <= 1'b0;
            dmem_pending <= 1'b0;
            current_addr <= 32'h0;
        end else begin
            case (mem_state)
                STATE_IDLE: begin
                    imem_ack <= 1'b0;
                    dmem_ack <= 1'b0;

                    // 优先处理数据存储器请求（写操作重要）
                    if (dmem_req && dmem_we) begin
                        mem_state <= STATE_RAM_WRITE;
                        current_addr <= dmem_addr;
                        write_data <= dmem_data_out;
                        write_sel <= dmem_sel;
                        is_write <= 1'b1;
                        dmem_pending <= 1'b1;
                    end
                    // 处理指令存储器请求
                    else if (imem_req) begin
                        // 检查缓存命中
                        if (cache_hit) begin
                            imem_data <= cache_data;
                            imem_ack <= 1'b1;
                            // 更新缓存LRU（简化）
                            icache_index <= hit_index;
                        end else begin
                            // 缓存未命中，根据地址范围选择存储器
                            if (in_ram_range) begin
                                mem_state <= STATE_RAM_READ;
                                ram_addr <= imem_addr - RAM_BASE;
                                ram_req <= 1'b1;
                            end else if (in_rom_range) begin
                                mem_state <= STATE_ROM_READ;
                                rom_addr <= imem_addr - ROM_BASE;
                                rom_req <= 1'b1;
                            end else if (in_flash_range) begin
                                mem_state <= STATE_FLASH_READ;
                                flash_addr <= imem_addr - FLASH_BASE;
                                flash_req <= 1'b1;
                            end else begin
                                // 地址错误，返回0
                                imem_data <= 32'h0;
                                imem_ack <= 1'b1;
                            end
                            current_addr <= imem_addr;
                            imem_pending <= 1'b1;
                        end
                    end
                    // 处理数据存储器读请求
                    else if (dmem_req && !dmem_we) begin
                        if (in_ram_range) begin
                            mem_state <= STATE_RAM_READ;
                            ram_addr <= dmem_addr - RAM_BASE;
                            ram_req <= 1'b1;
                        end else if (in_flash_range) begin
                            mem_state <= STATE_FLASH_READ;
                            flash_addr <= dmem_addr - FLASH_BASE;
                            flash_req <= 1'b1;
                        end else begin
                            dmem_data_in <= 32'h0;
                            dmem_ack <= 1'b1;
                        end
                        current_addr <= dmem_addr;
                        dmem_pending <= 1'b1;
                        is_write <= 1'b0;
                    end
                end

                STATE_RAM_READ: begin
                    if (ram_ack) begin
                        ram_req <= 1'b0;

                        if (imem_pending) begin
                            imem_data <= ram_data_in;
                            imem_ack <= 1'b1;
                            imem_pending <= 1'b0;

                            // 更新指令缓存
                            icache_addr[icache_index] <= current_addr;
                            icache_data[icache_index] <= ram_data_in;
                            icache_valid[icache_index] <= 1'b1;
                            icache_index <= icache_index + 1;
                        end else if (dmem_pending) begin
                            dmem_data_in <= ram_data_in;
                            dmem_ack <= 1'b1;
                            dmem_pending <= 1'b0;
                        end

                        mem_state <= STATE_IDLE;
                    end
                end

                STATE_ROM_READ: begin
                    if (rom_ack) begin
                        rom_req <= 1'b0;
                        imem_data <= rom_data;
                        imem_ack <= 1'b1;
                        imem_pending <= 1'b0;

                        // 更新指令缓存
                        icache_addr[icache_index] <= current_addr;
                        icache_data[icache_index] <= rom_data;
                        icache_valid[icache_index] <= 1'b1;
                        icache_index <= icache_index + 1;

                        mem_state <= STATE_IDLE;
                    end
                end

                STATE_FLASH_READ: begin
                    if (flash_ack) begin
                        flash_req <= 1'b0;

                        if (imem_pending) begin
                            imem_data <= flash_data;
                            imem_ack <= 1'b1;
                            imem_pending <= 1'b0;

                            // 更新指令缓存
                            icache_addr[icache_index] <= current_addr;
                            icache_data[icache_index] <= flash_data;
                            icache_valid[icache_index] <= 1'b1;
                        end else if (dmem_pending) begin
                            dmem_data_in <= flash_data;
                            dmem_ack <= 1'b1;
                            dmem_pending <= 1'b0;
                        end

                        mem_state <= STATE_IDLE;
                    end
                end

                STATE_RAM_WRITE: begin
                    ram_addr <= current_addr - RAM_BASE;
                    ram_data_out <= write_data;
                    ram_we <= 1'b1;
                    ram_sel <= write_sel;
                    ram_req <= 1'b1;

                    if (ram_ack) begin
                        ram_req <= 1'b0;
                        ram_we <= 1'b0;
                        dmem_ack <= 1'b1;
                        dmem_pending <= 1'b0;
                        mem_state <= STATE_IDLE;
                    end
                end

                STATE_FLASH_WRITE: begin
                    flash_addr <= current_addr - FLASH_BASE;
                    flash_data_out <= write_data;
                    flash_we <= 1'b1;
                    flash_req <= 1'b1;

                    if (flash_ack) begin
                        flash_req <= 1'b0;
                        flash_we <= 1'b0;
                        dmem_ack <= 1'b1;
                        dmem_pending <= 1'b0;
                        mem_state <= STATE_IDLE;
                    end
                end

                default: begin
                    mem_state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
