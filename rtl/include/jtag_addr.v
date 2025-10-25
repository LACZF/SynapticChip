`ifndef __JTAG_ADDR_V__
    `define __JTAG_ADDR_V__

    /********** 总线 **********/
    `define JTAG_ADDR_W           2       // 地址宽度
    `define JtagAddrBus           1:0     // 地址总线
    `define JtagAddrLoc           1:0     // 地址的位置
    /********** 地址图 **********/
    `define JTAG_ADDR_CTRL        2'h0    // 控制寄存器
    `define JTAG_ADDR_DATA        2'h1    // 数据寄存器
    `define JTAG_ADDR_STAT        2'h2    // 状态寄存器

`endif