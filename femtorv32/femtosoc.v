module femtosoc(
    input clk,          // why does clk work here
    output [2:0] leds,
    output tx
);

    // Reset
    // The Quark core requires reset=0 to reset, reset=1 to run.
    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt; // Becomes 1 after ~64 cycles
    always @(posedge clk) begin
        if (!resetn) reset_cnt <= reset_cnt + 1;
    end

    // Insantiation
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire        mem_rbusy = 0; // small setup, ram free
    wire        mem_wbusy = 0;

    FemtoRV32 cpu (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset(resetn)
    );

    // MMIO
    
    // Identify address ranges
    wire is_io  = (mem_addr[22] == 1'b1);
    wire is_ram = !is_io;

    // 4KB RAM
    reg [31:0] ram [0:1023]; // 1024 words * 4 bytes = 4KB
    
    // Read RAM
    assign mem_rdata = ram[mem_addr[11:2]]; // Word aligned read

    // Write RAM
    always @(posedge clk) begin
        if (is_ram && mem_wmask[0]) ram[mem_addr[11:2]][7:0]   <= mem_wdata[7:0];
        if (is_ram && mem_wmask[1]) ram[mem_addr[11:2]][15:8]  <= mem_wdata[15:8];
        if (is_ram && mem_wmask[2]) ram[mem_addr[11:2]][23:16] <= mem_wdata[23:16];
        if (is_ram && mem_wmask[3]) ram[mem_addr[11:2]][31:24] <= mem_wdata[31:24];
    end


    reg [2:0] led_reg;
    assign leds = !led_reg;

    always @(posedge clk) begin
        if (is_io && mem_wmask[0] && (mem_addr[3:0] == 4'h0)) begin
            led_reg <= mem_wdata[2:0];
        end
    end

    reg [8:0] tx_countdown;
    reg [3:0] tx_bits_remaining;
    reg [7:0] tx_data;
    reg       tx_out_reg = 1'b1;
    
    assign tx = tx_out_reg;

    always @(posedge clk) begin
        if (tx_countdown == 0) begin
            if (tx_bits_remaining != 0) begin
                tx_bits_remaining <= tx_bits_remaining - 1;
                tx_countdown <= 173; // Reset divider
                tx_out_reg   <= tx_data[0];
                tx_data      <= {1'b1, tx_data[7:1]}; // Shift
            end else if (is_io && mem_wmask[0] && (mem_addr[3:0] == 4'h4)) begin
                // Start sending new char
                tx_data <= mem_wdata[7:0];
                tx_bits_remaining <= 10; // Start(1) + Data(8) + Stop(1)
                tx_countdown <= 173;
                tx_out_reg <= 0; // Start bit
            end else begin
                tx_out_reg <= 1; // Idle
            end
        end else begin
            tx_countdown <= tx_countdown - 1;
        end
    end

    // Blink LEDs + Send 'A' ka program
    initial begin
        ram[0] = 32'h00100293; // li t0, 1
        ram[1] = 32'h00400337; // lui t1, 0x400 (IO Base)
        ram[2] = 32'h00532023; // sw t0, 0(t1) (Write LED)
        ram[3] = 32'h04132223; // sw t0, 4(t1) (Write UART 'A' approx)
        ram[4] = 32'hff5ff06f; // j 0 (Infinite Loop)
    end

endmodule

