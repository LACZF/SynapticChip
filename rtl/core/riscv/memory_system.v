// memory_system.v
module memory_system (
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [31:0] imem_addr,
    output wire [31:0] imem_data,
    input wire imem_req,
    output wire imem_ack,

    input wire [31:0] dmem_addr,
    input wire [31:0] dmem_data_out,
    output wire [31:0] dmem_data_in,
    input wire dmem_we,
    input wire [3:0] dmem_sel,
    input wire dmem_req,
    output wire dmem_ack,

    // 调试输出
    output wire [2:0] mem_state
);

    // 内部连接
    wire [31:0] ram_addr;
    wire [31:0] ram_data_out;
    wire [31:0] ram_data_in;
    wire ram_we;
    wire [3:0] ram_sel;
    wire ram_req;
    wire ram_ack;

    wire [31:0] rom_addr;
    wire [31:0] rom_data;
    wire rom_req;
    wire rom_ack;

    wire [31:0] flash_addr;
    wire [31:0] flash_data;
    wire flash_req;
    wire flash_ack;
    wire flash_we;
    wire [31:0] flash_data_out;

    // 存储器控制器
    memory_controller controller (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_req(imem_req),
        .imem_ack(imem_ack),
        .dmem_addr(dmem_addr),
        .dmem_data_out(dmem_data_out),
        .dmem_data_in(dmem_data_in),
        .dmem_we(dmem_we),
        .dmem_sel(dmem_sel),
        .dmem_req(dmem_req),
        .dmem_ack(dmem_ack),
        .ram_addr(ram_addr),
        .ram_data_out(ram_data_out),
        .ram_data_in(ram_data_in),
        .ram_we(ram_we),
        .ram_sel(ram_sel),
        .ram_req(ram_req),
        .ram_ack(ram_ack),
        .rom_addr(rom_addr),
        .rom_data(rom_data),
        .rom_req(rom_req),
        .rom_ack(rom_ack),
        .flash_addr(flash_addr),
        .flash_data(flash_data),
        .flash_req(flash_req),
        .flash_ack(flash_ack),
        .flash_we(flash_we),
        .flash_data_out(flash_data_out),
        .mem_state(mem_state)
    );

    // RAM实例
    ram #(
        .SIZE(65536)  // 64KB
    ) ram_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr(ram_addr),
        .data_in(ram_data_out),
        .data_out(ram_data_in),
        .we(ram_we),
        .sel(ram_sel),
        .req(ram_req),
        .ack(ram_ack)
    );

    // ROM实例
    rom #(
        .SIZE(1048576)  // 1MB
    ) rom_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr(rom_addr),
        .data_out(rom_data),
        .req(rom_req),
        .ack(rom_ack)
    );

    // Flash实例
    flash #(
        .SIZE(16777216)  // 16MB
    ) flash_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr(flash_addr),
        .data_in(flash_data_out),
        .data_out(flash_data),
        .we(flash_we),
        .req(flash_req),
        .ack(flash_ack)
    );

endmodule
