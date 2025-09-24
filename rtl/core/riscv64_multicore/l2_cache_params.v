// l2_cache_params.v
`ifndef L2_CACHE_PARAMS_V
`define L2_CACHE_PARAMS_V

// L2缓存参数
`define L2_CACHE_OFFSET_BITS   6       // 64字节缓存行
`define L2_CACHE_INDEX_BITS    10      // 1024组
`define L2_CACHE_TAG_BITS      48      // 64位地址 - 10 - 6 = 48位
`define L2_CACHE_LINE_SIZE     64      // 字节
`define L2_CACHE_NUM_LINES     1024    // 1024个缓存行
`define L2_CACHE_NUM_WAYS      8       // 8路组相联

// L2缓存状态
`define L2_CACHE_IDLE          3'b000
`define L2_CACHE_READ_HIT      3'b001
`define L2_CACHE_WRITE_HIT     3'b010
`define L2_CACHE_MISS          3'b011
`define L2_CACHE_FILL          3'b100
`define L2_CACHE_WRITE_BACK    3'b101
`define L2_CACHE_SNOOP         3'b110

// L2缓存一致性协议（MOESI）
`define MOESI_I                3'b000   // Invalid
`define MOESI_S                3'b001   // Shared
`define MOESI_E                3'b010   // Exclusive
`define MOESI_O                3'b011   // Owned
`define MOESI_M                3'b100   // Modified
`define MOESI_F                3'b101   // Forward

// 请求类型
`define REQ_TYPE_READ          2'b00
`define REQ_TYPE_WRITE         2'b01
`define REQ_TYPE_READ_EXCLUSIVE 2'b10

`endif
