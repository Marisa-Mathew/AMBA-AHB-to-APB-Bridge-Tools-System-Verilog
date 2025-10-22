// =====================================================
// AHB Master Testbench (drives simple transactions)
// =====================================================

module tb_ahb_to_apb;

    reg HCLK;
    reg HRESETn;

    // AHB master signals (to bridge)
    reg  [31:0] HADDR;
    reg  [1:0]  HTRANS;
    reg         HWRITE;
    reg  [31:0] HWDATA;
    reg         HSEL;
    wire [31:0] HRDATA;
    wire        HREADY;
    wire [1:0]  HRESP;

    // APB wires (from bridge to APB RAM)
    wire        PSEL;
    wire        PENABLE;
    wire [31:0] PADDR;
    wire        PWRITE;
    wire [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    // Instantiate the bridge
    ahb_to_apb_bridge bridge (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        .HWRITE(HWRITE),
        .HWDATA(HWDATA),
        .HSEL(HSEL),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP(HRESP),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    // Instantiate a simple APB RAM
    apb_ram ram (
        .PCLK(HCLK),
        .PRESETn(HRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    // Clock
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK; // 100 MHz-ish (10ns period)
    end

    // Test sequence
    initial begin
        // Init
        HRESETn = 0;
        HADDR = 32'b0;
        HTRANS = 2'b00;
        HWRITE = 1'b0;
        HWDATA = 32'b0;
        HSEL = 1'b0;
        #20;
        HRESETn = 1;
        #20;

        $display("[%0t] START TEST", $time);

        // Write 0xDEADBEEF to address 0x100 (word 0x100)
        ahb_write(32'h00000100, 32'hDEADBEEF);
        #40;

        // Read back from 0x100
        ahb_read(32'h00000100);
        #40;

        // Write to another address
        ahb_write(32'h00000204, 32'hA5A5A5A5); // address 0x204
        #40;

        // Read back
        ahb_read(32'h00000204);
        #40;

        $display("[%0t] TEST COMPLETE", $time);
        $finish;
    end

    // AHB master task: write
    task ahb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge HCLK);
            HADDR <= addr;
            HWDATA <= data;
            HWRITE <= 1'b1;
            HSEL <= 1'b1;
            HTRANS <= 2'b10; // NONSEQ
            // wait until bridge asserts HREADY high (i.e., transfer complete)
            wait (HREADY == 1'b0); // bridge will drive low when starting
            // wait for completion (bridge raises HREADY back to 1)
            wait (HREADY == 1'b1);
            @(posedge HCLK);
            // deassert signals
            HTRANS <= 2'b00;
            HSEL <= 1'b0;
            HWRITE <= 1'b0;
            $display("[%0t] AHB WRITE addr=0x%08h data=0x%08h HRESP=%0b", $time, addr, data, HRESP);
        end
    endtask

    // AHB master task: read
    task ahb_read(input [31:0] addr);
        reg [31:0] r;
        begin
            @(posedge HCLK);
            HADDR <= addr;
            HWRITE <= 1'b0;
            HSEL <= 1'b1;
            HTRANS <= 2'b10; // NONSEQ
            wait (HREADY == 1'b0);
            wait (HREADY == 1'b1);
            @(posedge HCLK);
            // capture HRDATA
            r = HRDATA;
            HTRANS <= 2'b00;
            HSEL <= 1'b0;
            $display("[%0t] AHB READ  addr=0x%08h data=0x%08h HRESP=%0b", $time, addr, r, HRESP);
        end
    endtask

endmodule