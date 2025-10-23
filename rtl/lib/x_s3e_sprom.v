
/********** 通用头文件 **********/

`include "stddef.v"
`include "global_config.v"

/********** 单个头文件 **********/
`include "rom.v"

/********** 模块 **********/
module x_s3e_sprom (
	input wire				  clka,	 // 时钟
	input wire [`RomAddrBus]  addra, // 读取地址
	output reg [`WordDataBus] douta	 // 读取的数据
);

	/********** 内存 **********/
	reg [`WordDataBus] mem [0:`ROM_DEPTH-1];

	/********** 读取访问 **********/
	always @(posedge clka) begin
		douta <= #1 mem[addra];
	end

endmodule
