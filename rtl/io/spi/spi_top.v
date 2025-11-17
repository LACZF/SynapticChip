
module spi_top #(
    parameter DATA_WIDTH             = 32,
    parameter ADDR_WIDTH             = 32,
    parameter SPI_NUM                = 1
) (
    input wire                       clk,
    input wire                       rst_n,

    // Control interface - OBI protocol
    input  wire                      req_i,
    input  wire                      we_i,
    input  wire [ADDR_WIDTH-1:0]     addr_i,
    input  wire [DATA_WIDTH-1:0]     data_in_i,
    output reg  [DATA_WIDTH-1:0]     data_out_o,
    output reg                       gnt_o,
    output reg                       rvalid_o,

    // SPI physical interface
    output reg  [SPI_NUM-1:0]        spi_cs_n_o,
    output reg                       spi_clk_o,
    output reg                       spi_mosi_o,
    input  wire                      spi_miso_i
);
    localparam SPI_REG_CONTROL       = 8'h00;
    localparam SPI_REG_STATUS        = 8'h04;
    localparam SPI_REG_DATA          = 8'h08;
    localparam SPI_REG_ADDR          = 8'h0C;
    localparam SPI_REG_CMD           = 8'h10;
    localparam SPI_REG_CLK_DIV       = 8'h14;
    localparam SPI_REG_CONFIG        = 8'h18;
    localparam SPI_REG_CS_SEL        = 8'h1C;

    localparam SPI_CTRL_EN           = 0;
    localparam SPI_CTRL_IRQ_EN       = 1;
    localparam SPI_CTRL_BUSY         = 2;
    localparam SPI_CTRL_READY        = 3;
    localparam SPI_CTRL_MASTER       = 4;

    localparam SPI_MODE_0            = 2'b00;
    localparam SPI_MODE_1            = 2'b01;
    localparam SPI_MODE_2            = 2'b10;
    localparam SPI_MODE_3            = 2'b11;

    localparam SPI_STATUS_TX_READY   = 0;
    localparam SPI_STATUS_RX_READY   = 1;
    localparam SPI_STATUS_BUSY       = 2;
    localparam SPI_STATUS_ERROR      = 3;
    localparam SPI_STATUS_IRQ_PEND   = 4;

    localparam SPI_STATE_IDLE        = 3'b000;
    localparam SPI_STATE_CMD         = 3'b001;
    localparam SPI_STATE_ADDR        = 3'b010;
    localparam SPI_STATE_DUMMY       = 3'b011;
    localparam SPI_STATE_READ        = 3'b100;
    localparam SPI_STATE_WRITE       = 3'b101;
    localparam SPI_STATE_TRANSFER    = 3'b110;
    localparam SPI_STATE_DONE        = 3'b111;

    localparam SPI_CMD_READ_DATA     = 8'h03;
    localparam SPI_CMD_FAST_READ     = 8'h0B;
    localparam SPI_CMD_READ_DUAL     = 8'h3B;
    localparam SPI_CMD_READ_QUAD     = 8'h6B;
    localparam SPI_CMD_WRITE_ENABLE  = 8'h06;
    localparam SPI_CMD_WRITE_DATA    = 8'h02;
    localparam SPI_CMD_TRANSFER      = 8'h04;

    // Internal registers
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] status_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [DATA_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] cmd_reg;
    reg [DATA_WIDTH-1:0] clk_div_reg;
    reg [DATA_WIDTH-1:0] config_reg;
    reg [DATA_WIDTH-1:0] cs_sel_reg;  // Chip select register
    reg                  req_accepted;  // OBI handshake register

    // SPI state machine variables
    reg [2:0]               state;
    reg [7:0]               bit_counter;
    reg [7:0]               byte_counter;
    reg [7:0]               current_cmd;
    reg [23:0]              current_addr;
    reg [DATA_WIDTH-1:0]    tx_data;
    reg [DATA_WIDTH-1:0]    rx_data;
    reg [3:0]               clk_divider;
    reg                     clk_gen;

    // Control signals
    wire       spi_en      = control_reg[SPI_CTRL_EN];
    wire       irq_en      = control_reg[SPI_CTRL_IRQ_EN];
    wire       master_mode = control_reg[SPI_CTRL_MASTER];
    wire [1:0] spi_mode    = config_reg[1:0];
    wire [7:0] clk_div     = clk_div_reg[7:0];

    // SPI clock generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider <= 4'h0;
            clk_gen     <= 1'b0;
            spi_clk_o   <= 1'b0;
        end else if (spi_en) begin
            clk_divider <= clk_divider + 1;
            if (clk_divider == clk_div) begin
                clk_divider <= 4'h0;
                clk_gen     <= ~clk_gen;

                // Set clock phase and polarity according to SPI mode
                case (spi_mode)
                    SPI_MODE_0: spi_clk_o <= clk_gen;
                    SPI_MODE_1: spi_clk_o <= ~clk_gen;
                    SPI_MODE_2: spi_clk_o <= ~clk_gen;
                    SPI_MODE_3: spi_clk_o <= clk_gen;
                endcase
            end
        end else begin
            clk_divider <= 4'h0;
            clk_gen     <= 1'b0;
            spi_clk_o   <= 1'b0;
        end
    end
    wire spi_clk_edge = (spi_mode == SPI_MODE_0 || spi_mode == SPI_MODE_2) ?
                        (clk_divider == clk_div && !clk_gen) :
                        (clk_divider == clk_div && clk_gen);

    // OBI handshake logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_accepted <= 1'b0;
            gnt_o        <= 1'b0;
            rvalid_o     <= 1'b0;
        end else begin
            // Grant logic
            if (req_i && !req_accepted) begin
                gnt_o        <= 1'b1;
                req_accepted <= 1'b1;
            end else if (!req_i) begin
                req_accepted <= 1'b0;
            end else if (rvalid_o) begin
                gnt_o        <= 1'b0;
                req_accepted <= 1'b0;
            end else begin
                gnt_o <= 1'b0;
            end
        end
    end

    // Register read/write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_reg <= 32'h0;
            status_reg  <= 32'h0;
            data_reg    <= 32'h0;
            addr_reg    <= 32'h0;
            cmd_reg     <= 32'h0;
            clk_div_reg <= 32'h00000007; // Default clock divider
            config_reg  <= 32'h0; // Default SPI mode 0
            data_out_o  <= 32'h0;
            rvalid_o    <= 1'b0;
        end else begin
            rvalid_o <= 1'b0;

            if (req_accepted) begin
                if (we_i) begin
                    // Write operation
                    case (addr_i[7:0])
                        SPI_REG_CONTROL: begin
                            control_reg <= data_in_i;
                            rvalid_o    <= 1'b1;
                        end
                        SPI_REG_DATA: begin
                            data_reg  <= data_in_i;
                            rvalid_o  <= 1'b1;
                        end
                        SPI_REG_ADDR: begin
                            addr_reg  <= data_in_i;
                            rvalid_o  <= 1'b1;
                        end
                        SPI_REG_CMD: begin
                            cmd_reg   <= data_in_i;
                            rvalid_o  <= 1'b1;
                            // Start SPI operation
                            if (spi_en) begin
                                current_cmd  <= data_in_i[7:0];
                                current_addr <= addr_reg[23:0];
                                tx_data      <= data_reg;
                                // TODO : support multi mode.
                                // state        <= SPI_STATE_CMD;
                                state        <= SPI_STATE_TRANSFER;
                                bit_counter  <= 8'h0;
                                byte_counter <= 8'h0;
                                spi_cs_n_o   <= ~(1 << cs_sel_reg[0 +: ($clog2(SPI_NUM) > 0 ? $clog2(SPI_NUM) : 1)]);
                                status_reg[SPI_STATUS_BUSY]     <= 1'b1;
                                status_reg[SPI_STATUS_TX_READY] <= 1'b0;
                            end
                        end
                        SPI_REG_CLK_DIV: begin
                            clk_div_reg <= data_in_i;
                            rvalid_o    <= 1'b1;
                        end
                        SPI_REG_CONFIG: begin
                            config_reg <= data_in_i;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_CS_SEL: begin  // Chip select register
                            cs_sel_reg <= data_in_i;
                            rvalid_o   <= 1'b1;
                        end
                    endcase
                end else begin
                    // Read operation
                    case (addr_i[7:0])
                        SPI_REG_CONTROL: begin
                            data_out_o <= control_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_STATUS: begin
                            data_out_o <= status_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_DATA: begin
                            data_out_o                       <= rx_data;
                            rvalid_o                         <= 1'b1;
                            status_reg[SPI_STATUS_RX_READY] <= 1'b0;
                        end
                        SPI_REG_ADDR: begin
                            data_out_o <= addr_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_CMD: begin
                            data_out_o <= cmd_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_CLK_DIV: begin
                            data_out_o <= clk_div_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_CONFIG: begin
                            data_out_o <= config_reg;
                            rvalid_o   <= 1'b1;
                        end
                        SPI_REG_CS_SEL: begin  // Chip select register
                            data_out_o <= cs_sel_reg;
                            rvalid_o   <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

    // SPI master state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= SPI_STATE_IDLE;
            bit_counter  <= 8'h0;
            byte_counter <= 8'h0;
            spi_cs_n_o   <= 1'b1;
            spi_mosi_o   <= 1'b0;
            rx_data      <= 32'h0;
            status_reg   <= 32'h0;
        end else if (spi_en) begin
            case (state)
                SPI_STATE_IDLE:
                    begin
                        status_reg[SPI_STATUS_TX_READY] <= 1'b1;
                        status_reg[SPI_STATUS_BUSY] <= 1'b0;
                    end

                SPI_STATE_CMD:
                    begin
                        // 首先设置下一位要发送的数据，提前一个cycle准备
                        if (spi_clk_edge) begin
                            if (bit_counter < 8) begin
                                bit_counter  <= bit_counter + 1;
                            end else begin
                                bit_counter  <= 8'h0;
                                byte_counter <= 8'h0;

                                // Determine next state based on command type
                                if (current_cmd == SPI_CMD_READ_DATA ||
                                    current_cmd == SPI_CMD_FAST_READ ||
                                    current_cmd == SPI_CMD_READ_DUAL ||
                                    current_cmd == SPI_CMD_READ_QUAD) begin
                                    state <= SPI_STATE_ADDR;
                                end else if (current_cmd == SPI_CMD_WRITE_ENABLE ||
                                            current_cmd == SPI_CMD_WRITE_DATA) begin
                                    if (current_cmd == SPI_CMD_WRITE_DATA) begin
                                        state <= SPI_STATE_ADDR;
                                    end else begin
                                        // Write enable command doesn't need address
                                        state <= SPI_STATE_DONE;
                                    end
                                end else if (current_cmd == SPI_CMD_TRANSFER) begin
                                    // Transfer command - simultaneous read and write
                                    state <= SPI_STATE_TRANSFER;
                                end else begin
                                    state <= SPI_STATE_DONE;
                                end
                            end
                        end else begin
                            // 提前准备下一位要发送的数据
                            if (state == SPI_STATE_CMD && bit_counter < 8) begin
                                spi_mosi_o <= current_cmd[7 - bit_counter[2:0]];
                            end
                        end
                    end

                SPI_STATE_ADDR:
                    begin
                        // 首先设置下一位要发送的数据，提前一个cycle准备
                        if (spi_clk_edge) begin
                            if (bit_counter < 24) begin  // 24-bit address
                                bit_counter <= bit_counter + 1;
                            end else begin
                                bit_counter <= 8'h0;

                                if (current_cmd == SPI_CMD_FAST_READ ||
                                    current_cmd == SPI_CMD_READ_DUAL ||
                                    current_cmd == SPI_CMD_READ_QUAD) begin
                                    state <= SPI_STATE_DUMMY;
                                end else if (current_cmd == SPI_CMD_WRITE_DATA) begin
                                    state <= SPI_STATE_WRITE;
                                end else if (current_cmd == SPI_CMD_TRANSFER) begin
                                    // For transfer command after address phase
                                    state <= SPI_STATE_TRANSFER;
                                end else begin
                                    state <= SPI_STATE_READ;
                                end
                            end
                        end else begin
                            // 提前准备下一位要发送的数据
                            if (state == SPI_STATE_ADDR && bit_counter < 24) begin
                                spi_mosi_o <= current_addr[23 - bit_counter[4:0]];
                            end
                        end
                    end

                SPI_STATE_DUMMY:
                    begin
                        if (spi_clk_edge) begin
                            if (bit_counter < 8) begin  // 8 dummy cycles
                                bit_counter <= bit_counter + 1;
                            end else begin
                                bit_counter <= 8'h0;
                                state       <= SPI_STATE_READ;
                            end
                        end
                    end

                SPI_STATE_READ:
                    begin
                        if (spi_clk_edge) begin
                            // Read data bits
                            rx_data     <= {rx_data[30:0], spi_miso_i};
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 31) begin  // 32-bit read complete
                                state                            <= SPI_STATE_DONE;
                                status_reg[SPI_STATUS_RX_READY] <= 1'b1;
                            end
                        end
                    end

                SPI_STATE_WRITE:
                    begin
                        // 首先设置下一位要发送的数据，提前一个cycle准备
                        if (spi_clk_edge) begin
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 31) begin  // 32-bit send complete
                                state <= SPI_STATE_DONE;
                            end
                        end else begin
                            // 提前准备下一位要发送的数据
                            if (state == SPI_STATE_WRITE) begin
                                spi_mosi_o <= tx_data[31 - bit_counter[4:0]];
                            end
                        end
                    end

                SPI_STATE_TRANSFER:
                    begin
                        // 首先设置下一位要发送的数据，提前一个cycle准备
                        if (spi_clk_edge) begin
                            // 接收数据
                            rx_data     <= {rx_data[30:0], spi_miso_i};  // RX
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 31) begin  // 32-bit transfer complete
                                state                            <= SPI_STATE_DONE;
                                status_reg[SPI_STATUS_RX_READY] <= 1'b1;
                            end
                        end else begin
                            // 提前准备下一位要发送的数据
                            spi_mosi_o <= tx_data[31 - bit_counter[4:0]];
                        end
                    end

                SPI_STATE_DONE:
                    begin
                        if (SPI_NUM > 1) begin
                            // Multi-chip select mode: pull up all CS signals
                            spi_cs_n_o <= {SPI_NUM{1'b1}};
                        end else begin
                            // Single-chip select mode: compatible with previous behavior
                            spi_cs_n_o <= 1'b1;
                        end
                        status_reg[SPI_STATUS_BUSY]     <= 1'b0;
                        status_reg[SPI_STATUS_TX_READY] <= 1'b1;

                        // Trigger interrupt
                        if (irq_en) begin
                            status_reg[SPI_STATUS_IRQ_PEND] <= 1'b1;
                        end

                        state <= SPI_STATE_IDLE;
                    end
            endcase
        end else begin
            state <= SPI_STATE_IDLE;
            if (SPI_NUM > 1) begin
                // Multi-chip select mode: pull up all CS signals
                spi_cs_n_o <= {SPI_NUM{1'b1}};
            end else begin
                // Single-chip select mode: compatible with previous behavior
                spi_cs_n_o <= 1'b1;
            end
            status_reg[SPI_STATUS_BUSY] <= 1'b0;
        end
    end

endmodule