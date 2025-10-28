`ifndef __PE_ADDR_V__
    `define __PE_ADDR_V__

    /********** PE基址 **********/
    `define PE_BASE_ADDR     32'h0000_0000

    /********** PE地址空间大小 **********/
    `define PE_ADDR_SIZE     32'h0000_0100

    /********** PE地址有效位 **********/
    `define PE_ADDR_MASK     `PE_ADDR_SIZE - 1
    `define PE_ADDR_LOC      31:0

    /********** PE寄存器偏移 **********/
    `define PE_CTRL_ADDR     32'h0000_0000  // 控制寄存器
    `define PE_STATUS_ADDR   32'h0000_0004  // 状态寄存器
    `define PE_INST_ADDR     32'h0000_0008  // 指令寄存器
    `define PE_DATA_ADDR     32'h0000_000C  // 数据寄存器
    `define PE_ROUTE_ADDR    32'h0000_0010  // 路由配置寄存器

    /********** PE控制寄存器位定义 **********/
    `define PE_EN_BIT        0              // 使能位
    `define PE_RESET_BIT     1              // 复位位

`endif