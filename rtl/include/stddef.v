
`ifndef __STDDEF_HEADER__
    `define __STDDEF_HEADER__

    `define HIGH                   1'b1
    `define LOW                    1'b0

    // 正逻辑
    `define DISABLE                1'b0     // 无效
    `define ENABLE                 1'b1     //    有效
    // 负逻辑
    `define DISABLE_N              1'b1     // 无效
    `define ENABLE_N               1'b0     // 有效

    `define READ                   1'b1     // 读取信号
    `define WRITE                  1'b0     // 写入信号

    // -----------------------------------------------------------------------------
    // 数据总线
    // -----------------------------------------------------------------------------
    /********** 最低位 *********/
    `define LSB                    0          // 最低位
    /********** 字节 (8 bit) *********/
    `define BYTE_DATA_W            8          // 数据宽度
    `define BYTE_MSB               7          // 最高位
    `define ByteDataBus            7:0        // 数据总线
    /********** 字 (32 bit) *********/
    `define WORD_DATA_W            32         // 数据总线
    `define WORD_MSB               31         // 最高位
    `define WordDataBus            31:0       // 数据总线

    // -----------------------------------------------------------------------------
    // 地址总线
    // -----------------------------------------------------------------------------
    /********** 字地址 *********/
    `define WORD_ADDR_W            30        // 地址宽度
    `define WORD_ADDR_MSB          29        // 最高位
    `define WordAddrBus            29:0      // 地址总线
    /********** 字节偏移 *********/
    `define BYTE_OFFSET_W          2         // 位移宽度
    `define ByteOffsetBus          1:0       // 位移总线
    /********** 地址位置 *********/
    `define WordAddrLoc            31:0      // 字地址位置
    `define ByteOffsetLoc          1:0       // 字节位移位置
    /********** 字节偏移值 *********/
    `define BYTE_OFFSET_WORD       2'b00     // 字边界

`endif
