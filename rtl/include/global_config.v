`ifndef __GLOBAL_CONFIG_HEADER__
	`define __GLOBAL_CONFIG_HEADER__	// 包含文件防范

	//------------------------------------------------------------------------------
	// 设定项目
	//------------------------------------------------------------------------------
	/********** 目标设备 : 选择1个 **********/
//	`define TARGET_DEV_MFPGA_SPAR3E		// Martz评估板
	`define TARGET_DEV_AZPR_EV_BOARD	// AZPR原始评估板

	/********** 复位信号极性 : 选择1个 **********/
//	`define POSITIVE_RESET				// Active High
	`define NEGATIVE_RESET				// Active Low

	/********** 内存控制信号极性 : 选择1个 **********/
	`define POSITIVE_MEMORY				// Active High
//	`define NEGATIVE_MEMORY				// Active Low

	/********** I/O设置 : 定义要实现的I/O **********/
	`define IMPLEMENT_TIMER				// 计时器
	`define IMPLEMENT_UART				// UART
	`define IMPLEMENT_GPIO				// General Purpose I/O
	`define IMPLEMENT_JTAG				// JTAG调试接口
	`define IMPLEMENT_SPI				// SPI接口
	`define IMPLEMENT_PE				// Processing Element

	`define SUPPORT_RV64M
	//------------------------------------------------------------------------------
	// 根据设置生成参数
	//------------------------------------------------------------------------------
	/********** 复位信号极性 *********/
	// Active Low
	`ifdef POSITIVE_RESET
		`define RESET_EDGE	  posedge	// 复位信号边沿
		`define RESET_ENABLE  1'b1		// 复位有效
		`define RESET_DISABLE 1'b0		// 复位无效
	`endif
	// Active High
	`ifdef NEGATIVE_RESET
		`define RESET_EDGE	  negedge	// 复位信号边沿
		`define RESET_ENABLE  1'b0		// 复位无效
		`define RESET_DISABLE 1'b1		// 复位有效
	`endif

	/********** 内存控制信号极性 *********/
	// Actoive High
	`ifdef POSITIVE_MEMORY
		`define MEM_ENABLE	  1'b1		// 内存有效
		`define MEM_DISABLE	  1'b0		// 内存无效
	`endif
	// Active Low
	`ifdef NEGATIVE_MEMORY
		`define MEM_ENABLE	  1'b0		// 内存无效
		`define MEM_DISABLE	  1'b1		// 内存有效
	`endif

`endif