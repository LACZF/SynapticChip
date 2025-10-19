// spi_node.v
// SPI node implementation, connecting SPI controller and Ring bus

`include "spi_params.v"

module spi_node #(
    parameter DATA_WIDTH                = 64,
    parameter ADDR_WIDTH                = 64,
    parameter SPI_CS_NUM                = 1,
    parameter NODE_ID_WIDTH             = 5
) (
    input wire                          clk,
    input wire                          rst_n,

    // Ring bus interface
    input wire [NODE_ID_WIDTH-1:0]      node_id_i,

    output reg                          spi_req_o,
    output reg                          spi_we_o,
    output reg  [ADDR_WIDTH-1:0]        spi_addr_o,
    output reg  [DATA_WIDTH-1:0]        spi_data_in_o,
    input  reg  [DATA_WIDTH-1:0]        spi_data_out_i,
    input  reg                          spi_ack_i,
    input  reg  [SPI_CS_NUM-1:0]        spi_cs_n_i,
    input  reg                          spi_clk_i,
    input  reg                          spi_mosi_i,
    output wire                         spi_miso_o,

    // Request interface
    input  wire                         req_valid_i,
    input  wire [NODE_ID_WIDTH-1:0]     req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        req_addr_i,
    input  wire [DATA_WIDTH-1:0]        req_data_i,
    input  wire                         req_we_i,

    // Response interface
    output reg                          rsp_valid_o,
    output reg  [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output reg  [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output reg  [ADDR_WIDTH-1:0]        rsp_addr_o,
    output reg  [DATA_WIDTH-1:0]        rsp_data_o
);
    // Internal state
    localparam IDLE    = 2'b00;
    localparam PROCESS = 2'b01;
    localparam RESPOND = 2'b10;

    reg [1:0] state;

    // Registers for saving request information
    reg [NODE_ID_WIDTH-1:0] saved_source_id;
    reg [NODE_ID_WIDTH-1:0] saved_target_id;
    reg [ADDR_WIDTH-1:0]    saved_addr;

    // Node state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            spi_req_o <= 1'b0;
            spi_we_o <= 1'b0;
            spi_addr_o <= 32'h0;
            spi_data_in_o <= 32'h0;
            rsp_valid_o <= 1'b0;
            rsp_source_id_o <= 0;
            rsp_target_id_o <= 0;
            rsp_addr_o <= 32'h0;
            rsp_data_o <= 32'h0;
        end else begin
            case (state)
                IDLE:
                    begin
                        rsp_valid_o <= 1'b0;
                        spi_req_o <= 1'b0;

                        // Check if there is a request and the target is this node
                        if (req_valid_i && (req_target_id_i == node_id_i)) begin
                            // Save request information
                            saved_source_id <= req_source_id_i;
                            saved_target_id <= req_target_id_i;
                            saved_addr <= req_addr_i;

                            // Set core controller signals
                            spi_we_o <= req_we_i;
                            spi_addr_o <= {24'h0, req_addr_i[7:0]}; // Only use lower 8 bits as register address
                            if (req_we_i) begin
                                spi_data_in_o <= req_data_i;
                            end

                            // Start core controller operation
                            spi_req_o <= 1'b1;
                            state <= PROCESS;
                        end
                    end

                PROCESS:
                    begin
                        // Wait for core controller to complete operation
                        if (spi_ack_i) begin
                            spi_req_o <= 1'b0;

                            // Prepare response
                            rsp_source_id_o <= node_id_i;
                            rsp_target_id_o <= saved_source_id;
                            rsp_addr_o <= saved_addr;

                            // If read operation, set the read data
                            if (!spi_we_o) begin
                                rsp_data_o <= spi_data_out_i;
                            end else begin
                                rsp_data_o <= 32'h0; // Write operation returns 0
                            end

                            state <= RESPOND;
                        end
                    end

                RESPOND:
                    begin
                        // Send response
                        rsp_valid_o <= 1'b1;
                        state <= IDLE;
                    end
            endcase
        end
    end

endmodule