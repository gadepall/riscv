module top (
    output wire tx,
    input wire rx,
    output wire led_blue,
    output wire led_green,
    output wire led_red
);

    // internal clock needed
    wire clk;

    // EOS S3 internal oscillator
    qlal4s3b_cell_macro u_qlal4s3b_cell_macro (
        .Sys_Clk0 (clk),    // System Clock
        .Sys_Clk1 (),
        .Sys_Clk0_Rst (),
        .Sys_Clk1_Rst ()
    );

    // Reset
    reg [3:0] reset_cnt = 0;
    wire resetn = &reset_cnt; 
    always @(posedge clk) reset_cnt <= reset_cnt + !resetn;

    // Memoery
    wire mem_valid;
    wire mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    
    //wire mem_is_rom = (mem_addr[31:28] == 4'h0);
    wire mem_is_rom = !mem_addr[29];
    //wire mem_is_io  = (mem_addr[31:28] == 4'h2);
    wire mem_is_io  = mem_addr[29];
    
    reg mem_ready_reg;
    wire mem_ready = mem_ready_reg;
    
    // case statement synthesizes to cheap LUTs, no FFs
    reg [31:0] rom_rdata;
    always @(*) begin
        case (mem_addr[6:2])
            5'd0:  rom_rdata = 32'h20000537; // lui a0, 0x20000 
            5'd1:  rom_rdata = 32'h00000593; // li a1, 0        
            5'd2:  rom_rdata = 32'h00500613; // li a2, 5        
            5'd3:  rom_rdata = 32'h00b52023; // sw a1, 0(a0)    
            5'd4:  rom_rdata = 32'h001006b7; // lui a3, 0x00100 
            5'd5:  rom_rdata = 32'hfff68693; // addi a3, a3, -1 
            5'd6:  rom_rdata = 32'hfe069ee3; // bnez a3, delay  
            5'd7:  rom_rdata = 32'h00158593; // addi a1, a1, 1  
            5'd8:  rom_rdata = 32'hfec59ae3; // bne a1, a2, loop
            5'd9:  rom_rdata = 32'h00000593; // li a1, 0        
            5'd10: rom_rdata = 32'hfe5ff06f; // j loop          
            default: rom_rdata = 32'h00000000;
        endcase
    end

    wire [31:0] mem_rdata = mem_is_rom ? rom_rdata : 32'h0;

    reg [2:0] led_reg;

    always @(posedge clk) begin
        if (!resetn) begin
            led_reg <= 3'b000;
            mem_ready_reg <= 1'b0;
        end else begin
            // PicoRV32 expects pulsing ready signal
            mem_ready_reg <= mem_valid && !mem_ready_reg;
            
            // Write Logic is ONLY for the LEDs now. We cannot write to ROM!!
            if (mem_valid && mem_is_io && |mem_wstrb) begin
                if (mem_wstrb[0]) led_reg <= mem_wdata[2:0];
            end
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
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_COUNTERS(0)
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
    assign rx = 1'b1;

    // MMIO Instantiation
    assign led_red   = led_reg[0];
    assign led_green = led_reg[1];
    assign led_blue  = led_reg[2];

endmodule
