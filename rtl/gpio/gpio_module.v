// gpio_module.v
// GPIO module implementation

`include "gpio_params.v"

module gpio_module #(
    parameter ADDR_WIDTH            = 64,
    parameter DATA_WIDTH            = 64,
    parameter GPIO_WIDTH            = 32
) (
    input                           clk,
    input                           rst_n,

    // Control interface
    input                           req_i,
    input                           we_i,
    input       [ADDR_WIDTH-1:0]    addr_i,
    input       [DATA_WIDTH-1:0]    data_in_i,
    output reg  [DATA_WIDTH-1:0]    data_out_o,
    output reg                      ack_o,

    // GPIO pins
    inout       [GPIO_WIDTH-1:0]    gpio_pins,

    // Interrupt output
    output reg                      int_out_o
);

    // Internal registers
    reg [GPIO_WIDTH-1:0] data_reg;     // Data register
    reg [GPIO_WIDTH-1:0] dir_reg;      // Direction register
    reg [GPIO_WIDTH-1:0] inten_reg;    // Interrupt enable register
    reg [GPIO_WIDTH-1:0] intpol_reg;   // Interrupt polarity register
    reg [GPIO_WIDTH-1:0] inttype_reg;  // Interrupt type register
    reg [GPIO_WIDTH-1:0] intstat_reg;  // Interrupt status register
    reg [15:0]           debounce_reg; // Debounce period register

    // Input synchronization and debouncing logic
    reg [GPIO_WIDTH-1:0] gpio_sync0;
    reg [GPIO_WIDTH-1:0] gpio_sync1;
    reg [GPIO_WIDTH-1:0] gpio_debounced;
    reg [15:0] debounce_counter [GPIO_WIDTH-1:0];
    reg [GPIO_WIDTH-1:0] debounce_active;

    // Interrupt detection logic
    reg [GPIO_WIDTH-1:0]  gpio_prev;
    wire [GPIO_WIDTH-1:0] gpio_rise;
    wire [GPIO_WIDTH-1:0] gpio_fall;

    // GPIO pin control
    genvar i;
    generate
        for (i = 0; i < GPIO_WIDTH; i = i + 1) begin : gpio_pin
            assign gpio_pins[i] = dir_reg[i] ? data_reg[i] : 1'bz;
        end
    endgenerate

    // Input synchronization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_sync0 <= {GPIO_WIDTH{1'b0}};
            gpio_sync1 <= {GPIO_WIDTH{1'b0}};
            gpio_prev <= {GPIO_WIDTH{1'b0}};
        end else begin
            gpio_sync0 <= gpio_pins;
            gpio_sync1 <= gpio_sync0;
            gpio_prev <= gpio_debounced;
        end
    end

    // Edge detection
    assign gpio_rise = gpio_debounced & ~gpio_prev;
    assign gpio_fall = ~gpio_debounced & gpio_prev;

    // Debouncing logic
    generate
        for (i = 0; i < GPIO_WIDTH; i = i + 1) begin : debounce
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    debounce_counter[i] <= 0;
                    debounce_active[i] <= 1'b0;
                    gpio_debounced[i] <= 1'b0;
                end else begin
                    if (gpio_sync1[i] != gpio_debounced[i] && !debounce_active[i]) begin
                        // Change detected, start debounce timer
                        debounce_active[i] <= 1'b1;
                        debounce_counter[i] <= debounce_reg;
                    end else if (debounce_active[i]) begin
                        if (debounce_counter[i] > 0) begin
                            debounce_counter[i] <= debounce_counter[i] - 1;
                        end else begin
                            // Debounce complete, update debounced value
                            debounce_active[i] <= 1'b0;
                            gpio_debounced[i] <= gpio_sync1[i];
                        end
                    end
                end
            end
        end
    endgenerate

    // Interrupt detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            intstat_reg <= {GPIO_WIDTH{1'b0}};
            int_out_o <= 1'b0;
        end else begin
            // Detect interrupt conditions
            for (integer j = 0; j < GPIO_WIDTH; j = j + 1) begin
                if (inten_reg[j]) begin
                    if (inttype_reg[j]) begin
                        // Edge interrupt
                        if ((intpol_reg[j] && gpio_rise[j]) || (!intpol_reg[j] && gpio_fall[j])) begin
                            intstat_reg[j] <= 1'b1;
                        end
                    end else begin
                        // Level interrupt
                        if ((intpol_reg[j] && gpio_debounced[j]) || (!intpol_reg[j] && !gpio_debounced[j])) begin
                            intstat_reg[j] <= 1'b1;
                        end
                    end
                end
            end

            // Generate interrupt signal
            int_out_o <= |(intstat_reg & inten_reg);
        end
    end

    // Register read/write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= {GPIO_WIDTH{1'b0}};
            dir_reg <= {GPIO_WIDTH{1'b0}};
            inten_reg <= {GPIO_WIDTH{1'b0}};
            intpol_reg <= {GPIO_WIDTH{1'b0}};
            inttype_reg <= {GPIO_WIDTH{1'b0}};
            debounce_reg <= 16'd1000; // Default debounce period
            ack_o <= 1'b0;
            data_out_o <= {DATA_WIDTH{1'b0}};
        end else begin
            ack_o <= 1'b0;

            if (req_i) begin
                if (we_i) begin
                    // Write operation
                    case (addr_i)
                        `REG_DATA: data_reg <= data_in_i[GPIO_WIDTH-1:0];
                        `REG_DIR: dir_reg <= data_in_i[GPIO_WIDTH-1:0];
                        `REG_INTEN: inten_reg <= data_in_i[GPIO_WIDTH-1:0];
                        `REG_INTPOL: intpol_reg <= data_in_i[GPIO_WIDTH-1:0];
                        `REG_INTTYPE: inttype_reg <= data_in_i[GPIO_WIDTH-1:0];
                        `REG_INTSTAT: intstat_reg <= intstat_reg & ~data_in_i[GPIO_WIDTH-1:0]; // Write 1 to clear
                        `REG_DEBOUNCE: debounce_reg <= data_in_i[15:0];
                    endcase
                end else begin
                    // Read operation
                    case (addr_i)
                        `REG_DATA: begin
                            // Set data register values bit by bit
                            for (integer k = 0; k < GPIO_WIDTH; k = k + 1) begin
                                data_out_o[k] <= dir_reg[k] ? data_reg[k] : gpio_debounced[k];
                            end
                            // If data width is greater than GPIO width, upper bits are zero-filled
                            if (DATA_WIDTH > GPIO_WIDTH) begin
                                data_out_o[DATA_WIDTH-1:GPIO_WIDTH] <= {(DATA_WIDTH-GPIO_WIDTH){1'b0}};
                            end
                        end
                        `REG_DIR: data_out_o <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, dir_reg};
                        `REG_INTEN: data_out_o <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, inten_reg};
                        `REG_INTPOL: data_out_o <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, intpol_reg};
                        `REG_INTTYPE: data_out_o <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, inttype_reg};
                        `REG_INTSTAT: data_out_o <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, intstat_reg};
                        `REG_DEBOUNCE: data_out_o <= {{(DATA_WIDTH-16){1'b0}}, debounce_reg};
                        default: data_out_o <= {DATA_WIDTH{1'b0}};
                    endcase
                end

                ack_o <= 1'b1;
            end
        end
    end

endmodule