// riscv64_soc_params.v
`ifndef RISCV64_SOC_PARAMS_V
`define RISCV64_SOC_PARAMS_V

// SoC configuration parameters
`define NUM_CORES         4
`define CORE_ID_WIDTH     2
`define SOC_CLK_FREQ      100_000_000  // 100MHz

// Address mapping
`define FLASH_BASE_ADDR   64'h0000_0000_0000_0000
`define FLASH_SIZE        64'h0100_0000              // 16MB Flash
`define SRAM_BASE_ADDR    64'h8000_0000
`define SRAM_SIZE         64'h0010_0000              // 1MB SRAM
`define MMIO_BASE_ADDR    64'hF000_0000
`define MMIO_SIZE         64'h1000_0000              // 256MB MMIO space

// Peripheral addresses
`define UART0_BASE        `MMIO_BASE_ADDR + 64'h0000_1000
`define SPI0_BASE         `MMIO_BASE_ADDR + 64'h0000_2000
`define GPIO0_BASE        `MMIO_BASE_ADDR + 64'h0000_3000
`define TIMER0_BASE       `MMIO_BASE_ADDR + 64'h0000_4000
`define PLIC_BASE         `MMIO_BASE_ADDR + 64'h0000_5000

// Flash parameters
`define FLASH_PAGE_SIZE   256         // bytes
`define FLASH_SECTOR_SIZE 4096        // bytes
`define FLASH_READ_DELAY  10          // clock cycles
`define FLASH_WRITE_DELAY 1000        // clock cycles

`endif