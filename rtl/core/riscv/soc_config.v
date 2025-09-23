// soc_config.v
`ifndef SOC_CONFIG_V
`define SOC_CONFIG_V

// 系统配置参数
`define RAM_SIZE       65536     // 64KB
`define ROM_SIZE       1048576   // 1MB
`define FLASH_SIZE     16777216  // 16MB

// 地址映射配置
`define RAM_BASE       32'h00000000
`define ROM_BASE       32'h10000000
`define FLASH_BASE     32'h20000000
`define TIMER_BASE     32'h30000000

// CPU配置
`define ENABLE_CACHE   1
`define CACHE_SIZE     8192      // 8KB缓存
`define PIPELINE_DEPTH 3

// 中断配置
`define NUM_EXT_INTS   8
`define TIMER_PRESCALE 100       // 定时器预分频

`endif
