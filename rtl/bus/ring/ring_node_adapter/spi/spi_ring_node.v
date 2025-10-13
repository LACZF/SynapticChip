// spi_ring_node.v
// SPI Ring node implementation, connecting SPI node and Ring bus

`include "ring_bus_params.v"
`include "spi_params.v"

module spi_ring_node #(
    parameter NUM_RINGS                 = 2,
    parameter ADDR_WIDTH                = 32,
    parameter DATA_WIDTH                = 64,
    parameter NODE_ID_WIDTH             = 8,
    parameter NODE_ID                   = 0,
    parameter OPCODE_WIDTH              = 8,
    parameter MATCH_TYPE_WIDTH          = 2,
    parameter SPI_CS_NUM                = 1,
    parameter TX_FIFO_DEPTH             = 4,
    parameter RX_FIFO_DEPTH             = 4,
    parameter RSP_FIFO_DEPTH            = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,

    output wire                         spi_req_o,
    output wire                         spi_we_o,
    output wire [ADDR_WIDTH-1:0]        spi_addr_o,
    output wire [DATA_WIDTH-1:0]        spi_data_in_o,
    input  reg  [DATA_WIDTH-1:0]        spi_data_out_i,
    input  reg                          spi_ack_i,
    input  reg  [SPI_CS_NUM-1:0]        spi_cs_n_i,
    input  reg                          spi_clk_i,
    input  reg                          spi_mosi_i,
    output wire                         spi_miso_o,

    // Send requests
    output wire [NUM_RINGS-1:0]         tx_req_ring_mask_o,      // Specify Ring to use
    output wire [NUM_RINGS-1:0]         tx_req_ring_disable_o,   // Disable Ring
    output wire                         tx_req_valid_o,
    output wire                         tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        tx_req_data_o,

    // Receive requests
    input  wire                         rx_req_valid_i,
    input  wire                         rx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      rx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        rx_req_data_i,

    // Receive responses
    input  wire                         rsp_valid_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rsp_addr_i,
    input  wire [DATA_WIDTH-1:0]        rsp_data_i
);
    // SPI node
    wire                                spi_node_rsp_valid;
    wire [NODE_ID_WIDTH-1:0]            spi_node_rsp_source_id;
    wire [NODE_ID_WIDTH-1:0]            spi_node_rsp_target_id;
    wire [ADDR_WIDTH-1:0]               spi_node_rsp_addr;
    wire [DATA_WIDTH-1:0]               spi_node_rsp_data;

    // Instantiate SPI node
    spi_node #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SPI_CS_NUM(SPI_CS_NUM),
        .NODE_ID_WIDTH(NODE_ID_WIDTH)
    ) u_spi_node (
        .clk(clk),
        .rst_n(rst_n),
        .node_id_i(NODE_ID[NODE_ID_WIDTH-1:0]),

        .spi_req_o(spi_req_o),
        .spi_we_o(spi_we_o),
        .spi_addr_o(spi_addr_o),
        .spi_data_in_o(spi_data_in_o),
        .spi_data_out_i(spi_data_out_i),
        .spi_ack_i(spi_ack_i),
        .spi_cs_n_i(spi_cs_n_i),
        .spi_clk_i(spi_clk_i),
        .spi_mosi_i(spi_mosi_i),
        .spi_miso_o(spi_miso_o),

        .req_valid_i(rx_req_valid_i && rx_req_opcode_i != `RING_OP_RESP),
        .req_source_id_i(rx_req_source_id_i),
        .req_target_id_i(rx_req_target_id_i),
        .req_addr_i(rx_req_addr_i),
        .req_data_i(rx_req_data_i),
        .req_we_i(rx_req_opcode_i == `RING_OP_WRITE),
        .rsp_valid_o(spi_node_rsp_valid),
        .rsp_source_id_o(spi_node_rsp_source_id),
        .rsp_target_id_o(spi_node_rsp_target_id),
        .rsp_addr_o(spi_node_rsp_addr),
        .rsp_data_o(spi_node_rsp_data)
    );

    // Process SPI node responses and forward them to Ring bus
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize
        end else begin
            // SPI node responses will be sent through ring_bus_node's response interface
            // No additional processing logic is needed here
        end
    end

endmodule