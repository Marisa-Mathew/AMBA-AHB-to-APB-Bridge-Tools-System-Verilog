Marisa Mathew, [09/10/2025 17:33]
`timescale 1ns/1ps

// =====================================================
// Simple AHB-to-APB Bridge (behavioural subset)
// =====================================================

module ahb_to_apb_bridge (
    input  wire        HCLK,
    input  wire        HRESETn,

    // AHB-lite slave interface (bridge acts as AHB slave)
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,   // 00=IDLE, 10=NONSEQ, 11=SEQ
    input  wire        HWRITE,
    input  wire [31:0] HWDATA,
    input  wire        HSEL,     // optional HSEL used by master-testbench
    output reg  [31:0] HRDATA,
    output reg         HREADY,   // indicate slave ready
    output reg  [1:0]  HRESP,    // OKAY=00, ERROR=01

    // APB master interface (bridge acts as APB master)
    output reg         PSEL,
    output reg         PENABLE,
    output reg  [31:0] PADDR,
    output reg         PWRITE,
    output reg  [31:0] PWDATA,
    input  wire [31:0] PRDATA,
    input  wire        PREADY,
    input  wire        PSLVERR
);

    // Simple state machine
    typedef enum reg [2:0] {
        IDLE  = 3'd0,
        SETUP = 3'd1,
        ACCESS = 3'd2,
        WAIT_PREADY = 3'd3,
        COMPLETE = 3'd4
    } state_t;

    reg [2:0] state, next_state;
    reg [31:0] saved_addr;
    reg saved_write;
    reg [31:0] saved_wdata;

    // Default values for outputs
    initial begin
        PSEL = 0;
        PENABLE = 0;
        PADDR = 32'b0;
        PWRITE = 0;
        PWDATA = 32'b0;
        HRDATA = 32'b0;
        HREADY = 1'b1;
        HRESP = 2'b00;
        state = IDLE;
    end

    // Next-state logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                // detect valid AHB transfer (NONSEQ or SEQ) and HSEL asserted
                if (HSEL && (HTRANS == 2'b10  HTRANS == 2'b11)) begin
                    next_state = SETUP;
                end else begin
                    next_state = IDLE;
                end
            end
            SETUP: begin
                next_state = ACCESS;
            end
            ACCESS: begin
                // Start APB access in this cycle; if PREADY is immediate, go to COMPLETE
                if (PREADY) next_state = COMPLETE;
                else next_state = WAIT_PREADY;
            end
            WAIT_PREADY: begin
                if (PREADY) next_state = COMPLETE;
                else next_state = WAIT_PREADY;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential state transitions and outputs (on HCLK)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
            PSEL <= 1'b0;
            PENABLE <= 1'b0;
            PADDR <= 32'b0;
            PWRITE <= 1'b0;
            PWDATA <= 32'b0;
            HRDATA <= 32'b0;
            HREADY <= 1'b1;
            HRESP <= 2'b00;
            saved_addr <= 32'b0;
            saved_write <= 1'b0;
            saved_wdata <= 32'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    // default idle outputs
                    PSEL <= 1'b0;
                    PENABLE <= 1'b0;
                    HREADY <= 1'b1;
                    HRESP <= 2'b00;
                    // capture incoming transfer if present
                    if (HSEL && (HTRANS == 2'b10  HTRANS == 2'b11)) begin
                        saved_addr <= HADDR;
                        saved_write <= HWRITE;
                        saved_wdata <= HWDATA;
                    end
                end

Marisa Mathew, [09/10/2025 17:33]
SETUP: begin
                    // start APB select (SETUP cycle)
                    PSEL <= 1'b1;
                    PENABLE <= 1'b0; // first cycle PSEL asserted, PENABLE low
                    PADDR <= saved_addr;
                    PWRITE <= saved_write;
                    PWDATA <= saved_wdata;
                    // while APB access is happening, AHB slave not ready
                    HREADY <= 1'b0;
                end

                ACCESS: begin
                    // second cycle: enable APB transfer
                    PENABLE <= 1'b1;
                    // If APB is ready immediately, we'll capture read data
                    if (PREADY) begin
                        if (!PWRITE) begin
                            HRDATA <= PRDATA;
                        end
                        // drive response based on PSLVERR
                        HRESP <= PSLVERR ? 2'b01 : 2'b00;
                        // deassert APB signals (we'll go to COMPLETE)
                        PSEL <= 1'b0;
                        PENABLE <= 1'b0;
                        HREADY <= 1'b1; // indicate transfer completed to AHB
                    end else begin
                        // wait for PREADY -> go to WAIT_PREADY
                        HREADY <= 1'b0;
                    end
                end

                WAIT_PREADY: begin
                    PENABLE <= 1'b1;
                    // keep PSEL asserted until PREADY
                    PSEL <= 1'b1;
                    if (PREADY) begin
                        // now complete
                        if (!PWRITE) HRDATA <= PRDATA;
                        HRESP <= PSLVERR ? 2'b01 : 2'b00;
                        PSEL <= 1'b0;
                        PENABLE <= 1'b0;
                        HREADY <= 1'b1;
                    end else begin
                        HREADY <= 1'b0;
                    end
                end

                COMPLETE: begin
                    // Completed; present HRDATA and HRESP already set
                    HREADY <= 1'b1;
                    PSEL <= 1'b0;
                    PENABLE <= 1'b0;
                end

                default: begin
                    PSEL <= 1'b0;
                    PENABLE <= 1'b0;
                    HREADY <= 1'b1;
                end
            endcase
        end
    end

endmodule


// =====================================================
// Simple APB RAM/Slave (behavioural) - small memory (words)
// =====================================================

module apb_ram (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output reg         PREADY,
    output reg         PSLVERR
);
    // small memory 256 words
    reg [31:0] mem [0:255];
    integer i;

    // initialize memory for demonstration
    initial begin
        for (i=0; i<256; i=i+1) mem[i] = 32'h0;
        PRDATA = 32'h0;
        PREADY = 1'b1;  // ready by default (can be stretched)
        PSLVERR = 1'b0;
    end

    // Simple APB transaction behaviour
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA <= 32'b0;
            PREADY <= 1'b1;
            PSLVERR <= 1'b0;
        end else begin
            // default ready = 1 (no wait state)
            PREADY <= 1'b1;
            PSLVERR <= 1'b0;
            if (PSEL && PENABLE) begin
                // decode address to 8-bit word index (word addressed)
                // simple aligned address: use bits [9:2] to index words (so base 0..255)
                // (addresses are byte addresses)
                reg [7:0] idx;
                idx = PADDR[9:2];
                if (PWRITE) begin
                    mem[idx] <= PWDATA;
                end else begin
                    PRDATA <= mem[idx];
                end
            end
        end
    end
endmodule