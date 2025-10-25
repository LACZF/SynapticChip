`ifndef __SPI_ADDR_V__
`define __SPI_ADDR_V__

//------------------------------------------------------------------------------
// SPI地址映射定义
//------------------------------------------------------------------------------
`define SPI_ADDR_BASE        32'h0000_0000            // SPI地址基址
`define SPI_ADDR_SIZE        32'h0000_0020            // SPI地址空间大小
`define SPI_ADDR_LOC         19:0                     // SPI地址的有效位

//------------------------------------------------------------------------------
// SPI寄存器地址偏移
//------------------------------------------------------------------------------
`define SPI_REG_CONTROL        8'h00                    // 控制寄存器
`define SPI_REG_STATUS         8'h04                    // 状态寄存器
`define SPI_REG_DATA           8'h08                    // 数据寄存器
`define SPI_REG_ADDR           8'h0C                    // 地址寄存器
`define SPI_REG_CMD            8'h10                    // 命令寄存器
`define SPI_REG_CLK_DIV        8'h14                    // 时钟分频寄存器
`define SPI_REG_CONFIG         8'h18                    // 配置寄存器
`define SPI_REG_CS_SEL         8'h1C                    // 片选寄存器

`endif