// memory_system_integrated.v
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

    // 具体存储器接口
    output wire [31:0] ram_addr,
    output wire [31:0] ram_data_out,
    input wire [31:0] ram_data_in,
    output wire ram_we,
    output wire [3:0] ram_sel,
    output wire ram_req,
    input wire ram_ack,

    output wire [31:0] rom_addr,
    output wire [31:0] rom_data,
    output wire rom_req,
    input wire rom_ack,

    output wire [31:0] flash_addr,
    output wire [31:0] flash_data,
    output wire flash_req,
    input wire flash_ack,
    output wire flash_we,
    output wire [31:0] flash_data_out,

    // 状态输出
    output wire [2:0] mem_state
);

    // 使用之前实现的memory_controller
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

endmodule
