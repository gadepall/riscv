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
    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;
    always @(posedge clk) reset_cnt <= reset_cnt + !resetn;

    // Memoery
    parameter MEM_SIZE = 32;
    reg [31:0] mem [0:MEM_SIZE-1];
    
    wire mem_valid;
    wire mem_instr;
    wire mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    integer i;
    initial begin
        for (i=0; i<MEM_SIZE; i=i+1) mem[i] = 0;
        mem[0] = 32'h0000006f; // "j 0"
    end

    assign mem_ready = 1'b1;
    assign mem_rdata = mem[(mem_addr >> 2) % MEM_SIZE];

    always @(posedge clk) begin
        if (mem_valid && |mem_wstrb) begin
            if (mem_wstrb[0]) mem[(mem_addr >> 2) % MEM_SIZE][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) mem[(mem_addr >> 2) % MEM_SIZE][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) mem[(mem_addr >> 2) % MEM_SIZE][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[(mem_addr >> 2) % MEM_SIZE][31:24] <= mem_wdata[31:24];
        end
    end

    // CPU Instantiation
    pico_opt #(
        .ENABLE_REGS_16_31(0),
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

    // Debug heartbeat
    reg [24:0] counter;
    always @(posedge clk) counter <= counter + 1;

   // Peripherals
    assign tx = counter[14]; 
    assign rx = 1'b1; 
    assign led_blue = counter[23];
    assign led_green = 1'b0; 
    assign led_red = 1'b0;   

endmodule
