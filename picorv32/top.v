module top (
    output wire tx,
    input wire rx,
    output wire led_blue,
    output wire led_green,
    output wire led_red
);
    // internal clock needed
    wire clk;
    qlal4s3b_cell_macro u_qlal4s3b_cell_macro (
        .Sys_Clk0 (clk),
        .Sys_Clk1 (),
        .Sys_Clk0_Rst (),
        .Sys_Clk1_Rst ()
    );

    // Reset
    reg [1:0] reset_cnt = 0;
    wire resetn = reset_cnt[1]; // Boots up in just 2 clock cycles
    always @(posedge clk) reset_cnt <= {reset_cnt[0], 1'b1};

    // MMIO
    wire mem_valid;
    wire mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    wire mem_ready = mem_valid; 

    reg [31:0] mem_rdata;
    always @(*) begin
        case (mem_addr[5:2])
            4'd0:  mem_rdata = 32'h00000593; // li a1, 0        (Counter)
            4'd1:  mem_rdata = 32'h00500613; // li a2, 5        (Limit)
            
            // loop:
            4'd2:  mem_rdata = 32'h04b02023; // sw a1, 64(zero) -> Write to LED at addr 0x40
            4'd3:  mem_rdata = 32'h001006b7; // lui a3, 0x00100 (Delay limit)
            
            // delay:
            4'd4:  mem_rdata = 32'hfff68693; // addi a3, a3, -1
            4'd5:  mem_rdata = 32'hfe069ee3; // bnez a3, delay  
            4'd6:  mem_rdata = 32'h00158593; // addi a1, a1, 1  
            4'd7:  mem_rdata = 32'hfec59ae3; // bne a1, a2, loop
            4'd8:  mem_rdata = 32'h00000593; // li a1, 0        
            4'd9:  mem_rdata = 32'hfe5ff06f; // j loop          
            default: mem_rdata = 32'h00000000;
        endcase
    end

    reg [2:0] led_reg;
    always @(posedge clk) begin
        if (!resetn) begin
            led_reg <= 3'b000;
        end 
        // 0x40 in binary is exactly bit 6! No 32-bit math required.
        else if (mem_valid && mem_addr[6] && mem_wstrb[0]) begin
            led_reg <= mem_wdata[2:0];
        end
    end

    // CPU Instantiation
    pico_opt #(
        .ENABLE_REGS_16_31(0),      
        .ENABLE_REGS_DUALPORT(0),   
        .BARREL_SHIFTER(0),         
        .TWO_STAGE_SHIFT(0),        
        .TWO_CYCLE_COMPARE(0),      
        .TWO_CYCLE_ALU(0),          
        .COMPRESSED_ISA(0),         
        .CATCH_MISALIGN(0),         
        .CATCH_ILLINSN(0),          
        .ENABLE_PCPI(0),            
        .ENABLE_TRACE(0),           
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0)       // Explicitly disabling 64-bit counters too
    ) cpu (
        .clk       (clk),
        .resetn    (resetn),
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata)
    );

   // Peripherals
    assign tx = 1'b1; 
    assign led_red   = led_reg[0];
    assign led_green = led_reg[1];
    assign led_blue  = led_reg[2];

endmodule
