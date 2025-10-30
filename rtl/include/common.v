
`ifndef __COMMON_HEADER__
    `define __COMMON_HEADER__

    `ifndef CALC_ADDR_MASK_BY_LENGTH
    `define CALC_ADDR_MASK_BY_LENGTH(base, length) ~((length) - 1)
    `endif
    `ifndef CALC_ADDR_MASK_BY_END_ADDR
    `define CALC_ADDR_MASK_BY_END_ADDR(base, end_addr) ~((end_addr) - (base))
    `endif

`endif
