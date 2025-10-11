`ifndef CACHE_SYSTEM_PARAMS_V
`define CACHE_SYSTEM_PARAMS_V

// Cache system parameters

// L1 instruction cache parameters
`define L1_ICACHE_LINE_SIZE         64      // bytes
`define L1_ICACHE_SIZE              4*1024  // 4KB
`define L1_ICACHE_ASSOCIATIVITY     4       // 4-way set associative
`define L1_ICACHE_ADDR_WIDTH        64      // 64-bit address
`define L1_ICACHE_DATA_WIDTH        32      // 32-bit data (single instruction)

// L1 data cache parameters
`define L1_DCACHE_LINE_SIZE         64      // bytes
`define L1_DCACHE_SIZE              4*1024  // 4KB
`define L1_DCACHE_ASSOCIATIVITY     4       // 4-way set associative
`define L1_DCACHE_ADDR_WIDTH        64      // 64-bit address
`define L1_DCACHE_DATA_WIDTH        64      // 64-bit data

// L2 cache parameters
`define L2_CACHE_LINE_SIZE          64      // bytes
`define L2_CACHE_SIZE               64*1024  // 64KB
`define L2_CACHE_ASSOCIATIVITY      8       // 8-way set associative
`define L2_CACHE_ADDR_WIDTH         64      // 64-bit address
`define L2_CACHE_DATA_WIDTH         512     // 512-bit data (8 64-bit words)

// L3 cache parameters (if enabled)
`define L3_CACHE_LINE_SIZE          64      // bytes
`define L3_CACHE_SIZE               256*1024 // 256KB
`define L3_CACHE_ASSOCIATIVITY      16      // 16-way set associative
`define L3_CACHE_ADDR_WIDTH         64      // 64-bit address
`define L3_CACHE_DATA_WIDTH         512     // 512-bit data (8 64-bit words)

// Replacement policies
`define REPLACEMENT_LRU             1       // LRU replacement policy
`define REPLACEMENT_FIFO            2       // FIFO replacement policy
`define REPLACEMENT_RANDOM          3       // Random replacement policy

// Cache levels
`define CACHE_LEVEL_L1              1       // L1 cache
`define CACHE_LEVEL_L2              2       // L2 cache
`define CACHE_LEVEL_L3              3       // L3 cache

// Cache coherence protocol states
`define CACHE_STATE_INVALID         2'b00   // Invalid
`define CACHE_STATE_SHARED          2'b01   // Shared
`define CACHE_STATE_EXCLUSIVE       2'b10   // Exclusive
`define CACHE_STATE_MODIFIED        2'b11   // Modified

`endif