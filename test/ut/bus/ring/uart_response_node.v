module uart_response_node #(
    parameter NODE_ID                   = 4,
    parameter ADDR_WIDTH                = 64,
    parameter DATA_WIDTH                = 64
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Ring bus interface
    output reg                          ring_req_valid_o,
    input  wire                         ring_req_ready_i,
    output reg  [ADDR_WIDTH-1:0]        ring_req_addr_o,
    output reg  [DATA_WIDTH-1:0]        ring_req_data_o,
    output reg                          ring_req_wr_o,
    output reg  [7:0]                   ring_req_dest_o,

    input  wire                         ring_resp_valid_i,
    output reg                          ring_resp_ready_o,
    input  wire [DATA_WIDTH-1:0]        ring_resp_data_i,
    input  wire                         ring_resp_error_i,

    // External response interface (to UART controller)
    output reg                          ext_resp_enable_o,
    output reg  [ADDR_WIDTH-1:0]        ext_resp_addr_o,
    output reg  [DATA_WIDTH-1:0]        ext_resp_data_o,
    output reg                          ext_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        ext_resp_data_i,
    input  wire                         ext_resp_ready_i,

    // UART physical interface
    input  wire                         uart_rx_i,
    output reg                          uart_tx_o,
    output reg                          uart_irq_o
);

    // UART registers
    reg [7:0]  uart_tx_data;
    reg [7:0]  uart_rx_data;
    reg        uart_tx_busy;
    reg        uart_rx_ready;
    reg [15:0] uart_baud_counter;
    localparam BAUD_DIV = 868; // 115200 baud @ 100MHz

    // State machine
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        PROCESS_REQUEST = 3'b001,
        UART_TX = 3'b010,
        UART_RX = 3'b011,
        SEND_RESPONSE = 3'b100
    } state_t;

    state_t current_state;

    // Request information registers
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_data;
    reg saved_wr;
    reg [7:0] saved_src_node;
    reg [DATA_WIDTH-1:0] response_data;

    // UART transmit state
    reg [3:0] tx_bit_count;
    reg [2:0] tx_state;

    // UART receive state
    reg [3:0] rx_bit_count;
    reg [2:0] rx_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            ring_resp_ready_o <= 1'b0;
            ext_resp_enable_o <= 1'b0;
            uart_tx_o <= 1'b1;
            uart_irq_o <= 1'b0;
            uart_tx_busy <= 1'b0;
            uart_rx_ready <= 1'b0;
            tx_state <= 0;
            rx_state <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (ring_resp_valid_i) begin
                        // Receive request from Ring bus
                        saved_addr <= ring_resp_data_i[ADDR_WIDTH-1:0];
                        saved_wr <= ring_resp_data_i[32];
                        saved_data <= ring_resp_data_i[63:32];
                        saved_src_node <= 0; // Simplified handling

                        ring_resp_ready_o <= 1'b1;
                        current_state <= PROCESS_REQUEST;
                    end

                    // UART receive logic
                    if (rx_state == 0 && !uart_rx_i) begin
                        // Detect start bit
                        rx_state <= 1;
                        uart_baud_counter <= BAUD_DIV / 2;
                        rx_bit_count <= 0;
                    end
                end

                PROCESS_REQUEST: begin
                    ring_resp_ready_o <= 1'b0;

                    // Process UART request
                    if (saved_wr) begin
                        // UART write operation (send data)
                        uart_tx_data <= saved_data[7:0];
                        uart_tx_busy <= 1'b1;
                        tx_state <= 1;
                        uart_baud_counter <= BAUD_DIV;
                        uart_tx_o <= 1'b0; // Start bit
                        response_data <= {56'h0, 8'h55}; // Send success response
                    end else begin
                        // UART read operation (read status or data)
                        if (saved_addr[3:0] == 0) begin
                            // Read data register
                            response_data <= {56'h0, uart_rx_data};
                            uart_rx_ready <= 1'b0;
                        end else begin
                            // Read status register
                            response_data <= {62'h0, uart_rx_ready, uart_tx_busy};
                        end
                    end

                    current_state <= SEND_RESPONSE;
                end

                SEND_RESPONSE: begin
                    // Send response back to source node
                    ring_req_valid_o <= 1'b1;
                    ring_req_data_o <= response_data;
                    ring_req_wr_o <= 1'b0;
                    ring_req_dest_o <= saved_src_node;

                    if (ring_req_ready_i) begin
                        ring_req_valid_o <= 1'b0;
                        current_state <= IDLE;
                    end
                end
            endcase

            // UART transmit state machine
            case (tx_state)
                1: begin // Send start bit
                    if (uart_baud_counter == 0) begin
                        tx_state <= 2;
                        uart_baud_counter <= BAUD_DIV;
                        tx_bit_count <= 0;
                        uart_tx_o <= uart_tx_data[0];
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
                2: begin // Send data bits
                    if (uart_baud_counter == 0) begin
                        if (tx_bit_count == 7) begin
                            tx_state <= 3;
                            uart_tx_o <= 1'b1; // Stop bit
                        end else begin
                            tx_bit_count <= tx_bit_count + 1;
                            uart_tx_o <= uart_tx_data[tx_bit_count + 1];
                        end
                        uart_baud_counter <= BAUD_DIV;
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
                3: begin // Send stop bit
                    if (uart_baud_counter == 0) begin
                        tx_state <= 0;
                        uart_tx_busy <= 1'b0;
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
            endcase

            // UART receive state machine
            case (rx_state)
                1: begin // Receive start bit
                    if (uart_baud_counter == 0) begin
                        rx_state <= 2;
                        uart_baud_counter <= BAUD_DIV;
                        rx_bit_count <= 0;
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
                2: begin // Receive data bits
                    if (uart_baud_counter == 0) begin
                        uart_rx_data[rx_bit_count] <= uart_rx_i;
                        if (rx_bit_count == 7) begin
                            rx_state <= 3;
                        end else begin
                            rx_bit_count <= rx_bit_count + 1;
                        end
                        uart_baud_counter <= BAUD_DIV;
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
                3: begin // Receive stop bit
                    if (uart_baud_counter == 0) begin
                        rx_state <= 0;
                        uart_rx_ready <= 1'b1;
                        uart_irq_o <= 1'b1;
                    end else begin
                        uart_baud_counter <= uart_baud_counter - 1;
                    end
                end
            endcase

            if (uart_irq_o) begin
                uart_irq_o <= 1'b0;
            end
        end
    end

endmodule