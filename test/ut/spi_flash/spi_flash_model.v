module spi_flash_model (
    input cs_n,
    input sck,
    input mosi,
    output reg miso,  // 改为reg类型以支持过程赋值
    input wp_n,
    input hold_n
);

// 参数
parameter MEM_SIZE = 1024*1024;  // 1MB Flash
parameter ID_CODE = 32'h20BA16;  // N25Q制造商和设备ID

// 内部存储器
reg [7:0] memory [0:MEM_SIZE-1];
reg [7:0] status_reg;
reg [7:0] config_reg;
reg [7:0] flag_reg;

// 状态寄存器位定义
parameter SR_WIP = 0;      // Write in Progress
parameter SR_WEL = 1;      // Write Enable Latch
parameter SR_BP0 = 2;      // Block Protect 0
parameter SR_BP1 = 3;      // Block Protect 1
parameter SR_BP2 = 4;      // Block Protect 2
parameter SR_BP3 = 5;      // Block Protect 3
parameter SR_QE = 6;       // Quad Enable
parameter SR_SRWD = 7;     // Status Register Write Protect

// 操作状态
localparam [3:0]
    STANDBY          = 4'd0,
    CMD_DECODE       = 4'd1,
    READ_DATA        = 4'd2,
    FAST_READ_DATA   = 4'd3,
    READ_STATUS      = 4'd4,
    READ_ID          = 4'd5,
    WRITE_ENABLE     = 4'd6,
    WRITE_DISABLE    = 4'd7,
    PAGE_PROGRAM     = 4'd8,
    SECTOR_ERASE     = 4'd9,
    BULK_ERASE       = 4'd10,
    WRITE_STATUS     = 4'd11;

// 内部信号
reg [3:0] state;
reg [3:0] next_state;
reg [7:0] cmd_reg;
reg [23:0] addr_reg;
reg [7:0] bit_cnt;
reg [7:0] data_cnt;
reg [3:0] dummy_cnt;
reg [7:0] shift_in;
reg [7:0] shift_out;
reg hold_state;
reg write_enable;

// 初始化
integer i;
initial begin
    status_reg = 8'h00;
    config_reg = 8'h00;
    flag_reg = 8'h00;
    write_enable = 1'b0;
    state = STANDBY;
    bit_cnt = 8'd0;
    data_cnt = 8'd0;
    dummy_cnt = 4'd0;
    shift_in = 8'd0;
    shift_out = 8'd0;
    miso = 1'bz;

    // 初始化存储器内容
    for (i = 0; i < MEM_SIZE; i = i + 1) begin
        memory[i] = 8'hFF;  // Flash擦除后为0xFF
    end

    // 写入一些测试数据（RISC-V指令）
    memory[0] = 8'h13;  // FENCE指令 (0x00000013)
    memory[1] = 8'h00;
    memory[2] = 8'h00;
    memory[3] = 8'h00;

    memory[4] = 8'h6F;  // JAL指令 (0x0000006F)
    memory[5] = 8'h00;
    memory[6] = 8'h00;
    memory[7] = 8'h00;

    memory[8] = 8'hEF;  // JAL指令 (0x000000EF)
    memory[9] = 8'h00;
    memory[10] = 8'h00;
    memory[11] = 8'h00;

    memory[12] = 8'h37;  // LUI指令 (0x00000037)
    memory[13] = 8'h00;
    memory[14] = 8'h00;
    memory[15] = 8'h00;

    $display("SPI Flash Model Initialized with RISC-V instructions");
    $display("Address 0x000000: 0x%08h", {memory[3], memory[2], memory[1], memory[0]});
    $display("Address 0x000004: 0x%08h", {memory[7], memory[6], memory[5], memory[4]});
    $display("Address 0x000008: 0x%08h", {memory[11], memory[10], memory[9], memory[8]});
    $display("Address 0x00000C: 0x%08h", {memory[15], memory[14], memory[13], memory[12]});
end

// 输入移位寄存器（在SCK上升沿采样）
always @(posedge sck or negedge cs_n) begin
    if (!cs_n) begin
        shift_in <= {shift_in[6:0], mosi};
        bit_cnt <= bit_cnt + 8'd1;
    end
end

// 输出移位寄存器（在SCK下降沿更新）
always @(negedge sck or negedge cs_n) begin
    if (!cs_n) begin
        miso <= shift_out[7];
        shift_out <= {shift_out[6:0], 1'b0};
    end else begin
        miso <= 1'bz;
        shift_out <= 8'd0;
    end
end

// 状态寄存器
always @(posedge sck or negedge cs_n) begin
    if (!cs_n) begin
        state <= next_state;
    end else begin
        state <= STANDBY;
        bit_cnt <= 8'd0;
        data_cnt <= 8'd0;
        dummy_cnt <= 4'd0;
    end
end

// 下一状态逻辑和输出逻辑
always @(*) begin
    next_state = state;
    case (state)
        STANDBY: begin
            if (!cs_n && bit_cnt == 8) begin
                cmd_reg = shift_in;
                case (shift_in)
                    8'h03: next_state = READ_DATA;      // READ
                    8'h0B: next_state = FAST_READ_DATA; // FAST READ
                    8'h05: next_state = READ_STATUS;    // READ STATUS
                    8'h06: next_state = WRITE_ENABLE;   // WRITE ENABLE
                    8'h04: next_state = WRITE_DISABLE;  // WRITE DISABLE
                    8'h02: next_state = PAGE_PROGRAM;   // PAGE PROGRAM
                    8'h20: next_state = SECTOR_ERASE;   // SECTOR ERASE
                    8'h60: next_state = BULK_ERASE;     // BULK ERASE
                    8'h9F: next_state = READ_ID;        // READ ID
                    8'h01: next_state = WRITE_STATUS;   // WRITE STATUS
                    default: next_state = STANDBY;
                endcase
            end
        end

        READ_DATA: begin
            if (bit_cnt == 8'd32) begin  // 24位地址 + 8位命令
                addr_reg = {shift_in, addr_reg[23:8]};
                shift_out = memory[addr_reg];
                data_cnt = 8'd1;
            end else if (bit_cnt > 8'd32 && (bit_cnt % 8'd8) == 8'd0) begin
                addr_reg = addr_reg + 24'd1;
                shift_out = memory[addr_reg];
                data_cnt = data_cnt + 8'd1;
            end
        end

        FAST_READ_DATA: begin
            if (bit_cnt == 8'd32) begin  // 24位地址
                addr_reg = {shift_in, addr_reg[23:8]};
                dummy_cnt = 4'd1;
            end else if (bit_cnt > 8'd32 && dummy_cnt < 4'd8) begin
                dummy_cnt = dummy_cnt + 4'd1;
                shift_out = 8'h00;
            end else if (dummy_cnt == 4'd8 && (bit_cnt % 8'd8) == 8'd0) begin
                addr_reg = addr_reg + 24'd1;
                shift_out = memory[addr_reg];
                data_cnt = data_cnt + 8'd1;
            end
        end

        READ_STATUS: begin
            if (bit_cnt >= 8'd8) begin
                shift_out = status_reg;
                // WIP位在写入操作时置位
                if (status_reg[SR_WIP]) begin
                    status_reg[SR_WIP] = 1'b0;
                    status_reg[SR_WEL] = 1'b0;
                end
            end
        end

        READ_ID: begin
            case (data_cnt)
                8'd0: shift_out = 8'h20;  // 制造商ID
                8'd1: shift_out = 8'hBA;  // 设备ID高字节
                8'd2: shift_out = 8'h16;  // 设备ID低字节
                default: shift_out = 8'h00;
            endcase
            if (bit_cnt > 8'd8 && (bit_cnt % 8'd8) == 8'd0) begin
                data_cnt = data_cnt + 8'd1;
            end
        end

        WRITE_ENABLE: begin
            if (bit_cnt >= 8'd8) begin
                status_reg[SR_WEL] = 1'b1;
                write_enable = 1'b1;
                $display("[FLASH] Write Enabled");
            end
        end

        WRITE_DISABLE: begin
            if (bit_cnt >= 8'd8) begin
                status_reg[SR_WEL] = 1'b0;
                write_enable = 1'b0;
                $display("[FLASH] Write Disabled");
            end
        end

        PAGE_PROGRAM: begin
            if (bit_cnt == 8'd32) begin
                addr_reg = {shift_in, addr_reg[23:8]};
                $display("[FLASH] Page Program at address 0x%06h", addr_reg);
            end else if (bit_cnt > 8'd32 && (bit_cnt % 8'd8) == 8'd0) begin
                if (write_enable && addr_reg < MEM_SIZE) begin
                    memory[addr_reg] = shift_in & memory[addr_reg];
                    $display("[FLASH] Write 0x%02h to address 0x%06h", shift_in, addr_reg);
                    addr_reg = addr_reg + 24'd1;
                    status_reg[SR_WIP] = 1'b1;
                end
            end
        end

        SECTOR_ERASE: begin
            if (bit_cnt == 8'd32) begin
                addr_reg = {shift_in, addr_reg[23:8]};
                // 对齐到4KB扇区边界
                addr_reg = {addr_reg[23:12], 12'h000};
                $display("[FLASH] Sector Erase at address 0x%06h", addr_reg);
                if (write_enable) begin
                    for (i = 0; i < 4096; i = i + 1) begin
                        memory[addr_reg + i] = 8'hFF;
                    end
                    status_reg[SR_WIP] = 1'b1;
                    $display("[FLASH] Sector 0x%06h erased", addr_reg);
                end
            end
        end

        default: begin
            next_state = STANDBY;
        end
    endcase
end

// WP#和HOLD#引脚处理
always @(*) begin
    if (!hold_n) begin
        hold_state = 1'b1;
    end else begin
        hold_state = 1'b0;
    end
end

endmodule