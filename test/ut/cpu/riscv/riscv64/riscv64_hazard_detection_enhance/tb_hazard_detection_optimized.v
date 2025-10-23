module tb_hazard_detection_optimized;
    // 测试优化后的冒险检测单元

    // 测试精细化的stall控制
    initial begin
        // 测试Load-Use冒险
        $display("Testing Load-Use Hazard...");
        // 设置场景：EX阶段是load指令，ID阶段需要相同寄存器
        setup_load_use_hazard();
        #10;
        verify_stall_signals(1, 1, 0, 0, 0,  // stall_if, stall_id, stall_ex, stall_mem, stall_wb
                             0, 0, 1, 0);     // flush_if, flush_id, flush_ex, flush_mem

        // 测试控制冒险
        $display("Testing Control Hazard...");
        setup_control_hazard();
        #10;
        verify_stall_signals(0, 0, 0, 0, 0,  // 无stall
                             1, 1, 1, 0);     // 刷新IF,ID,EX

        // 测试结构冒险
        $display("Testing Structural Hazard...");
        setup_structural_hazard();
        #10;
        verify_stall_signals(1, 0, 0, 0, 0,  // 只stall IF
                             0, 0, 0, 0);     // 无flush

        // 测试前向功能
        $display("Testing Forwarding...");
        setup_forwarding_scenario();
        #10;
        verify_forwarding_signals(2'b10, 2'b00); // forward_a从EX阶段

        $display("All hazard detection tests completed!");
    end

    task setup_load_use_hazard;
        begin
            // EX阶段：lw x1, 0(x2)
            id_ex_inst = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; // lw指令格式
            ex_rd = 5'd1;
            ex_reg_write = 1'b1;
            ex_mem_to_reg = 2'b01; // load指令

            // ID阶段：add x3, x1, x4 (使用x1)
            if_id_inst = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; // add指令格式
            id_rs1 = 5'd1;
            id_rs2 = 5'd4;
        end
    endtask

    task verify_stall_signals;
        input s_if, s_id, s_ex, s_mem, s_wb;
        input f_if, f_id, f_ex, f_mem;
        begin
            if (stall_if === s_if && stall_id === s_id && stall_ex === s_ex &&
                stall_mem === s_mem && stall_wb === s_wb &&
                flush_if === f_if && flush_id === f_id &&
                flush_ex === f_ex && flush_mem === f_mem) begin
                $display("PASS: Stall/Flush signals correct");
            end else begin
                $display("FAIL: Expected stall(%b,%b,%b,%b,%b) flush(%b,%b,%b,%b), Got stall(%b,%b,%b,%b,%b) flush(%b,%b,%b,%b)",
                         s_if, s_id, s_ex, s_mem, s_wb, f_if, f_id, f_ex, f_mem,
                         stall_if, stall_id, stall_ex, stall_mem, stall_wb,
                         flush_if, flush_id, flush_ex, flush_mem);
            end
        end
    endtask

    // 其他测试任务...

endmodule