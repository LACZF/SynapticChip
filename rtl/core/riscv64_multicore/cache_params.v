// cache_params.v
`ifndef CACHE_PARAMS_V
`define CACHE_PARAMS_V

// 缓存参数
`define CACHE_OFFSET_BITS   6       // 64字节缓存行
`define CACHE_INDEX_BITS    6       // 64组
`define CACHE_TAG_BITS      52      // 64位地址 - 6 - 6 = 52位
`define CACHE_LINE_SIZE     64      // 字节
`define CACHE_NUM_LINES     64      // 64个缓存行
`define CACHE_NUM_WAYS      4       // 4路组相联

// 缓存状态
`define CACHE_IDLE          3'b000
`define CACHE_READ_HIT      3'b001
`define CACHE_WRITE_HIT     3'b010
`define CACHE_MISS          3'b011
`define CACHE_FILL          3'b100
`define CACHE_WRITE_BACK    3'b101

// 缓存一致性协议
`define MESI_I              2'b00   // Invalid
`define MESI_S              2'b01   // Shared
`define MESI_E              2'b10   // Exclusive
`define MESI_M              2'b11   // Modified

`endif
