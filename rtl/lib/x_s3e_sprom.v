

`include "stddef.v"
`include "global_config.v"

`include "rom.v"

module x_s3e_sprom (
    input  wire                 clka,     // 时钟
    input  wire [`RomAddrBus]   addra,    // 读取地址
    output reg [`WordDataBus]   douta     // 读取的数据
);

    /********** 内存 **********/
    reg [`WordDataBus] mem [0:`ROM_DEPTH-1];

    /********** 读取访问 **********/
    always @(posedge clka) begin
        douta <= mem[addra>>2];
    end

endmodule
