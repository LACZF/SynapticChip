`ifndef CACHE_SYSTEM_PARAMS_V
`define CACHE_SYSTEM_PARAMS_V

// 缓存系统参数

// L1指令缓存参数
`define L1_ICACHE_LINE_SIZE         64      // 字节
`define L1_ICACHE_SIZE              4*1024  // 4KB
`define L1_ICACHE_ASSOCIATIVITY     4       // 4路组相联
`define L1_ICACHE_ADDR_WIDTH        64      // 64位地址
`define L1_ICACHE_DATA_WIDTH        32      // 32位数据（单条指令）

// L1数据缓存参数
`define L1_DCACHE_LINE_SIZE         64      // 字节
`define L1_DCACHE_SIZE              4*1024  // 4KB
`define L1_DCACHE_ASSOCIATIVITY     4       // 4路组相联
`define L1_DCACHE_ADDR_WIDTH        64      // 64位地址
`define L1_DCACHE_DATA_WIDTH        64      // 64位数据

// L2缓存参数
`define L2_CACHE_LINE_SIZE          64      // 字节
`define L2_CACHE_SIZE               64*1024  // 64KB
`define L2_CACHE_ASSOCIATIVITY      8       // 8路组相联
`define L2_CACHE_ADDR_WIDTH         64      // 64位地址
`define L2_CACHE_DATA_WIDTH         512     // 512位数据（8个64位字）

// L3缓存参数（如果启用）
`define L3_CACHE_LINE_SIZE          64      // 字节
`define L3_CACHE_SIZE               256*1024 // 256KB
`define L3_CACHE_ASSOCIATIVITY      16      // 16路组相联
`define L3_CACHE_ADDR_WIDTH         64      // 64位地址
`define L3_CACHE_DATA_WIDTH         512     // 512位数据（8个64位字）

// 替换策略
`define REPLACEMENT_LRU             1       // LRU替换策略
`define REPLACEMENT_FIFO            2       // FIFO替换策略
`define REPLACEMENT_RANDOM          3       // 随机替换策略

// 缓存级别
`define CACHE_LEVEL_L1              1       // L1缓存
`define CACHE_LEVEL_L2              2       // L2缓存
`define CACHE_LEVEL_L3              3       // L3缓存

// 缓存一致性协议状态
`define CACHE_STATE_INVALID         2'b00   // 无效
`define CACHE_STATE_SHARED          2'b01   // 共享
`define CACHE_STATE_EXCLUSIVE       2'b10   // 独占
`define CACHE_STATE_MODIFIED        2'b11   // 修改

`endif