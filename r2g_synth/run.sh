PWD=$(cd "$(dirname "$0")";pwd)

export RTL_FILE="${PWD}/rtl/Alu.sv ${PWD}/rtl/Arbiter3_RegfileWriteDataIO.sv ${PWD}/rtl/Arbiter4_MluCmd.sv ${PWD}/rtl/AxiSlave.sv ${PWD}/rtl/Bru_1.sv ${PWD}/rtl/Bru.sv ${PWD}/rtl/cf_math_pkg.sv ${PWD}/rtl/CircularBufferMulti.sv ${PWD}/rtl/ClockGate.sv ${PWD}/rtl/CoralNPURRArbiter.sv ${PWD}/rtl/CoreCSR.sv ${PWD}/rtl/CoreMiniAxi.sv ${PWD}/rtl/CoreMini.sv ${PWD}/rtl/Csr.sv ${PWD}/rtl/DBus2AxiV1.sv ${PWD}/rtl/Decode_1.sv ${PWD}/rtl/Decode_2.sv ${PWD}/rtl/Decode_3.sv ${PWD}/rtl/Decode.sv ${PWD}/rtl/DispatchV1.sv ${PWD}/rtl/Dvu.sv ${PWD}/rtl/FabricArbiter.sv ${PWD}/rtl/FabricMux.sv ${PWD}/rtl/FaultManager.sv ${PWD}/rtl/FetchControl.sv ${PWD}/rtl/Fetcher.sv ${PWD}/rtl/FifoX_1.sv ${PWD}/rtl/FifoX_3.sv ${PWD}/rtl/FifoX.sv ${PWD}/rtl/FloatCore.sv ${PWD}/rtl/FloatCoreWrapper.sv ${PWD}/rtl/fpnew_cast_multi.sv ${PWD}/rtl/fpnew_classifier.sv ${PWD}/rtl/fpnew_divsqrt_th_32.sv ${PWD}/rtl/fpnew_fma_multi.sv ${PWD}/rtl/fpnew_fma.sv ${PWD}/rtl/fpnew_noncomp.sv ${PWD}/rtl/fpnew_opgroup_block.sv ${PWD}/rtl/fpnew_opgroup_fmt_slice.sv ${PWD}/rtl/fpnew_opgroup_multifmt_slice.sv ${PWD}/rtl/fpnew_pkg.sv ${PWD}/rtl/fpnew_rounding.sv ${PWD}/rtl/fpnew_top.sv ${PWD}/rtl/FRegfile.sv ${PWD}/rtl/gated_clk_cell.v ${PWD}/rtl/InstructionBuffer.sv ${PWD}/rtl/LsuV1.sv ${PWD}/rtl/lzc.sv ${PWD}/rtl/Mlu.sv ${PWD}/rtl/pa_fdsu_ctrl.v ${PWD}/rtl/pa_fdsu_ff1.v ${PWD}/rtl/pa_fdsu_pack_single.v ${PWD}/rtl/pa_fdsu_prepare.v ${PWD}/rtl/pa_fdsu_round_single.v ${PWD}/rtl/pa_fdsu_special.v ${PWD}/rtl/pa_fdsu_srt_single.v ${PWD}/rtl/pa_fdsu_top.v ${PWD}/rtl/pa_fpu_dp.v ${PWD}/rtl/pa_fpu_frbus.v ${PWD}/rtl/pa_fpu_src_type.v ${PWD}/rtl/Queue1_FloatInstruction.sv ${PWD}/rtl/Queue1_MluStage1.sv ${PWD}/rtl/Queue1_MluStage2.sv ${PWD}/rtl/Queue1_RWAxiAddress.sv ${PWD}/rtl/Queue2_AxiAddress.sv ${PWD}/rtl/Queue2_AxiReadData.sv ${PWD}/rtl/Queue2_AxiWriteData.sv ${PWD}/rtl/Queue2_AxiWriteResponse.sv ${PWD}/rtl/Queue2_RegfileWriteDataIO.sv ${PWD}/rtl/ram_2x137.sv ${PWD}/rtl/ram_2x145.sv ${PWD}/rtl/ram_2x37.sv ${PWD}/rtl/ram_2x67.sv ${PWD}/rtl/ram_2x8.sv ${PWD}/rtl/Regfile.sv ${PWD}/rtl/rr_arb_tree.sv ${PWD}/rtl/RstSync.sv ${PWD}/rtl/SCore.sv ${PWD}/rtl/Slice_1.sv ${PWD}/rtl/Slice_2.sv ${PWD}/rtl/Slice_4.sv ${PWD}/rtl/Slice.sv ${PWD}/rtl/SRAM_1.sv ${PWD}/rtl/SRAM_2048x128.sv ${PWD}/rtl/Sram_2048x128.v ${PWD}/rtl/SRAM_512x128.sv ${PWD}/rtl/Sram_512x128.v ${PWD}/rtl/SRAM.sv ${PWD}/rtl/TCM128_1.sv ${PWD}/rtl/TCM128.sv ${PWD}/rtl/UncachedFetch.sv"
# export FILELIST=""
export TOP_NAME="CoreMiniAxi"
export CLK_FREQ_MHZ="100"

export RESULT_DIR="${PWD}/result"
export NETLIST_FILE="${RESULT_DIR}/${TOP_NAME}_synth.v"
export TIMING_CELL_STAT_RPT="${RESULT_DIR}/timing_cell_stat.rpt"
export TIMING_CELL_COUNT_RPT="${RESULT_DIR}/timing_cell_count.rpt"
export GENERIC_STAT_JSON="${RESULT_DIR}/generic_stat.json"
export SYNTH_STAT_JSON="${RESULT_DIR}/synth_stat.json"
export SYNTH_CHECK_RPT="${RESULT_DIR}/synth_check.rpt"

export KEEP_HIERARCHY="false"
export CELL_DONT_USE=""
export CELL_TIE_LOW="TIELOH7R"
export CELL_TIE_LOW_PORT="Z"
export CELL_TIE_HIGH="TIEHIH7R"
export CELL_TIE_HIGH_PORT="Z"
export LIB_STDCELL="${PWD}/lib_ics55/ics55_LLSC_H7CL_ss_rcworst_1p08_125_nldm.lib ${PWD}/lib_ics55/ics55_LLSC_H7CR_ss_rcworst_1p08_125_nldm.lib"
export LIB_ALL=$LIB_STDCELL

yosys ${PWD}/yosys/scripts/yosys_synthesis.tcl
