// uart_core.v
// UART core module implementation

`include "uart_params.v"

module uart_core #(
    parameter ADDR_WIDTH             = 64,
    parameter DATA_WIDTH             = 64,
    parameter FIFO_DEPTH             = 16,
    parameter FIFO_ADDR_WIDTH        = 4
) (
    input                            clk,
    input                            rst_n,

    // Control interface
    input                            req_i,
    input                            we_i,
    input       [ADDR_WIDTH-1:0]     addr_i,
    input       [DATA_WIDTH-1:0]     data_in_i,
    output reg  [DATA_WIDTH-1:0]     data_out_o,
    output reg                       ack_o,

    // Serial interface
    output reg                       txd_o,        // Transmit data line
    input                            rxd_i,        // Receive data line
    output reg                       rts_o,        // Request to send (optional)
    input                            cts_i,        // Clear to send (optional)

    // Interrupt output
    output reg                       int_out_o
);

    // Internal registers
    reg [7:0]  rbr;         // Receive buffer register
    reg [7:0]  thr;         // Transmit holding register
    reg [7:0]  ier;         // Interrupt enable register
    reg [7:0]  iir;         // Interrupt identification register
    reg [7:0]  fcr;         // FIFO control register
    reg [7:0]  lcr;         // Line control register
    reg [7:0]  mcr;         // Modem control register
    reg [7:0]  lsr;         // Line status register
    reg [7:0]  msr;         // Modem status register
    reg [7:0]  scr;         // Scratch register
    reg [15:0] dll_dlm;     // Divisor latch registers

    // Baud rate generation
    reg [15:0] baud_counter;
    reg        baud_tick;

    // Transmit state machine
    reg [3:0] tx_state;
    reg [7:0] tx_shift;
    reg [3:0] tx_bit_count;
    reg       tx_parity;

    // Receive state machine
    reg [3:0] rx_state;
    reg [7:0] rx_shift;
    reg [3:0] rx_bit_count;
    reg       rx_parity;
    reg       rxd_sync;

    // FIFO buffers
    reg [7:0]                 rx_fifo [0:FIFO_DEPTH-1];
    reg [7:0]                 tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_WIDTH-1:0] rx_head, rx_tail;
    reg [FIFO_ADDR_WIDTH-1:0] tx_head, tx_tail;
    reg                       rx_full, rx_empty;
    reg                       tx_full, tx_empty;

    // Input signal synchronization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync <= 1'b1;
        end else begin
            rxd_sync <= rxd_i;
        end
    end

    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_counter == dll_dlm - 1) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end

    // Transmit state machine
    parameter TX_IDLE = 4'b0000;
    parameter TX_START = 4'b0001;
    parameter TX_DATA = 4'b0010;
    parameter TX_PARITY = 4'b0011;
    parameter TX_STOP = 4'b0100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            txd_o <= 1'b1;
            tx_shift <= 8'b0;
            tx_bit_count <= 0;
            tx_parity <= 0;
        end else if (baud_tick) begin
            case (tx_state)
                TX_IDLE: begin
                    if (!tx_empty) begin
                        // Read data from FIFO
                        tx_shift <= tx_fifo[tx_tail];
                        tx_tail <= tx_tail + 1;
                        tx_empty <= (tx_tail + 1 == tx_head);
                        tx_full <= 0;

                        tx_state <= TX_START;
                        txd_o <= 1'b0; // Start bit
                        tx_bit_count <= 0;
                        tx_parity <= 0;
                    end
                end

                TX_START: begin
                    tx_state <= TX_DATA;
                end

                TX_DATA: begin
                    txd_o <= tx_shift[0];
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_parity <= tx_parity ^ tx_shift[0];

                    if (tx_bit_count == (lcr[1:0] + 4'd5)) begin
                        tx_bit_count <= 0;
                        if (lcr[3]) begin
                            tx_state <= TX_PARITY; // With parity
                        end else begin
                            tx_state <= TX_STOP; // Without parity
                        end
                    end else begin
                        tx_bit_count <= tx_bit_count + 1;
                    end
                end

                TX_PARITY: begin
                    txd_o <= (lcr[4] ? ~tx_parity : tx_parity); // Parity bit
                    tx_state <= TX_STOP;
                end

                TX_STOP: begin
                    txd_o <= 1'b1; // Stop bit
                    if (tx_bit_count == (lcr[2] ? 1'd1 : 1'd0)) begin
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_bit_count <= tx_bit_count + 1;
                    end
                end
            endcase
        end
    end

    // Receive state machine
    parameter RX_IDLE = 4'b0000;
    parameter RX_START = 4'b0001;
    parameter RX_DATA = 4'b0010;
    parameter RX_PARITY = 4'b0011;
    parameter RX_STOP = 4'b0100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_shift <= 8'b0;
            rx_bit_count <= 0;
            rx_parity <= 0;
            rx_head <= 0;
            rx_tail <= 0;
            rx_empty <= 1;
            rx_full <= 0;
            lsr <= 8'b0; // Initialize line status register
        end else if (baud_tick) begin
            case (rx_state)
                RX_IDLE: begin
                    if (!rxd_sync) begin // Detect start bit
                        rx_state <= RX_START;
                        rx_bit_count <= 0;
                        rx_parity <= 0;
                    end
                end

                RX_START: begin
                    if (!rxd_sync) begin // Confirm start bit
                        rx_state <= RX_DATA;
                        rx_shift <= 8'b0;
                    end else begin
                        rx_state <= RX_IDLE; // False start bit
                    end
                end

                RX_DATA: begin
                    rx_shift <= {rx_shift[6:0], rxd_sync};
                    rx_parity <= rx_parity ^ rxd_sync;

                    if (rx_bit_count == 7) begin
                        rx_bit_count <= 0;
                        if (lcr[3]) begin
                            rx_state <= RX_PARITY; // With parity
                        end else begin
                            rx_state <= RX_STOP; // Without parity
                        end
                    end else begin
                        rx_bit_count <= rx_bit_count + 1;
                    end
                end

                RX_PARITY: begin
                    if (lcr[4] ? (rx_parity != rxd_sync) : (rx_parity == rxd_sync)) begin
                        // Parity error
                        lsr[2] <= 1'b1;
                    end
                    rx_state <= RX_STOP;
                end

                RX_STOP: begin
                    if (!rxd_sync) begin
                        // Frame error (stop bit not 1)
                        lsr[3] <= 1'b1;
                    end

                    // Store data into FIFO
                    if (!rx_full) begin
                        rx_fifo[rx_head] <= rx_shift;
                        rx_head <= rx_head + 1;
                        rx_empty <= 0;
                        rx_full <= (rx_head + 1 == rx_tail);

                        // Set data ready flag
                        lsr[0] <= 1'b1;
                    end else begin
                        // FIFO overflow
                        lsr[1] <= 1'b1;
                    end

                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end

    // Interrupt generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iir <= {4'b0, `INT_NONE};
            int_out_o <= 0;
        end else begin
            // Check interrupt conditions
            if ((ier[0] && !rx_empty) ||          // Receive data available
                (ier[1] && !tx_full) ||           // Transmit holding register empty
                (ier[2] && (lsr[2] || lsr[3])) || // Receive line status error
                (ier[3] && msr[0])) begin         // Modem status change

                // Set highest priority interrupt
                if (ier[2] && (lsr[2] || lsr[3])) begin
                    iir <= {4'b0, `INT_LS};
                end else if (ier[0] && !rx_empty) begin
                    iir <= {4'b0, `INT_RX};
                end else if (ier[1] && !tx_full) begin
                    iir <= {4'b0, `INT_TX};
                end else if (ier[3] && msr[0]) begin
                    iir <= {4'b0, `INT_MS};
                end

                int_out_o <= 1;
            end else begin
                iir <= {4'b0, `INT_NONE};
                int_out_o <= 0;
            end
        end
    end

    // Register read/write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thr <= 8'b0;
            ier <= 8'b0;
            fcr <= 8'b0;
            lcr <= 8'b0;
            mcr <= 8'b0;
            scr <= 8'b0;
            dll_dlm <= 16'd12; // Default baud rate 115200 @ 100MHz
            ack_o <= 1'b0;
            data_out_o <= {DATA_WIDTH{1'b0}};
        end else begin
            ack_o <= 1'b0;

            if (req_i) begin
                if (we_i) begin
                    // Write operation
                    case (addr_i)
                        `REG_THR: begin
                            if (!tx_full) begin
                                tx_fifo[tx_head] <= data_in_i[7:0];
                                tx_head <= tx_head + 1;
                                tx_empty <= 0;
                                tx_full <= (tx_head + 1 == tx_tail);
                            end
                        end
                        `REG_IER: ier <= data_in_i[7:0];
                        `REG_FCR: fcr <= data_in_i[7:0];
                        `REG_LCR: lcr <= data_in_i[7:0];
                        `REG_MCR: mcr <= data_in_i[7:0];
                        `REG_SCR: scr <= data_in_i[7:0];
                        `REG_DLL: if (lcr[7]) dll_dlm[7:0] <= data_in_i[7:0];
                        `REG_DLM: if (lcr[7]) dll_dlm[15:8] <= data_in_i[7:0];
                    endcase
                end else begin
                    // Read operation
                    case (addr_i)
                        `REG_RBR: begin
                            if (!rx_empty) begin
                                data_out_o <= {24'b0, rx_fifo[rx_tail]};
                                rx_tail <= rx_tail + 1;
                                rx_full <= 0;
                                rx_empty <= (rx_tail + 1 == rx_head);

                                if (rx_tail + 1 == rx_head) begin
                                    lsr[0] <= 1'b0; // Clear data ready flag
                                end
                            end
                        end
                        `REG_IER: data_out_o <= {24'b0, ier};
                        `REG_IIR: data_out_o <= {24'b0, iir};
                        `REG_LCR: data_out_o <= {24'b0, lcr};
                        `REG_MCR: data_out_o <= {24'b0, mcr};
                        `REG_LSR: data_out_o <= {24'b0, lsr};
                        `REG_MSR: data_out_o <= {24'b0, msr};
                        `REG_SCR: data_out_o <= {24'b0, scr};
                        `REG_DLL: if (lcr[7]) data_out_o <= {24'b0, dll_dlm[7:0]};
                        `REG_DLM: if (lcr[7]) data_out_o <= {24'b0, dll_dlm[15:8]};
                        default: data_out_o <= {DATA_WIDTH{1'b0}};
                    endcase
                end

                ack_o <= 1'b1;
            end
        end
    end

endmodule