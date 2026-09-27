module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    input  logic                  wr_clk,
    input  logic                  rd_clk,
    input  logic                  rst_n,

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  full,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  empty
);

    // =========================================================
    // Parameters
    // =========================================================

    localparam int DEPTH    = (1 << ADDR_WIDTH);
    localparam int PTR_WIDTH = ADDR_WIDTH + 1;


    // =========================================================
    // FIFO MEMORY
    // =========================================================

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];


    // =========================================================
    // WRITE POINTERS
    // =========================================================

    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] wr_ptr_gray;

    logic [PTR_WIDTH-1:0] wr_ptr_bin_next;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_next;


    // =========================================================
    // READ POINTERS
    // =========================================================

    logic [PTR_WIDTH-1:0] rd_ptr_bin;
    logic [PTR_WIDTH-1:0] rd_ptr_gray;

    logic [PTR_WIDTH-1:0] rd_ptr_bin_next;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_next;


    // =========================================================
    // SYNCHRONIZED POINTERS
    //
    // Write pointer crossing into READ clock domain
    // =========================================================

    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync1;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync2;


    // Read pointer crossing into WRITE clock domain

    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync1;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync2;


    // =========================================================
    // NEXT FULL / EMPTY
    // =========================================================

    logic full_next;
    logic empty_next;


    // =========================================================
    // WRITE POINTER NEXT-STATE LOGIC
    // =========================================================

    always_comb begin

        wr_ptr_bin_next = wr_ptr_bin;

        // Write only when FIFO is not full
        if (wr_en && !full)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;

    end


    // =========================================================
    // BINARY → GRAY
    //
    // Gray = Binary XOR (Binary >> 1)
    // =========================================================

    always_comb begin

        wr_ptr_gray_next =
            wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    end


    // =========================================================
    // WRITE POINTER REGISTER
    // =========================================================

    always_ff @(posedge wr_clk or negedge rst_n) begin

        if (!rst_n) begin

            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;

        end
        else begin

            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;

        end

    end


    // =========================================================
    // WRITE MEMORY
    // =========================================================

    always_ff @(posedge wr_clk) begin

        if (wr_en && !full) begin

            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wdata;

        end

    end


    // =========================================================
    // READ POINTER NEXT-STATE LOGIC
    // =========================================================

    always_comb begin

        rd_ptr_bin_next = rd_ptr_bin;

        // Read only when FIFO is not empty
        if (rd_en && !empty)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;

    end


    // =========================================================
    // BINARY → GRAY
    // =========================================================

    always_comb begin

        rd_ptr_gray_next =
            rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    end


    // =========================================================
    // READ POINTER REGISTER
    // =========================================================

    always_ff @(posedge rd_clk or negedge rst_n) begin

        if (!rst_n) begin

            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;

        end
        else begin

            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;

        end

    end


    // =========================================================
    // READ MEMORY
    // =========================================================

    always_ff @(posedge rd_clk) begin

        if (rd_en && !empty) begin

            rdata <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

        end

    end


    // =========================================================
    // WRITE POINTER → READ CLOCK DOMAIN
    //
    // 2-FLOP SYNCHRONIZER
    // =========================================================

    always_ff @(posedge rd_clk or negedge rst_n) begin

        if (!rst_n) begin

            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;

        end
        else begin

            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;

        end

    end


    // =========================================================
    // READ POINTER → WRITE CLOCK DOMAIN
    //
    // 2-FLOP SYNCHRONIZER
    // =========================================================

    always_ff @(posedge wr_clk or negedge rst_n) begin

        if (!rst_n) begin

            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;

        end
        else begin

            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;

        end

    end


    // =========================================================
    // EMPTY DETECTION
    //
    // FIFO is empty when the NEXT read pointer equals
    // the synchronized write pointer.
    // =========================================================

    always_comb begin

        empty_next =
            (rd_ptr_gray_next == wr_ptr_gray_sync2);

    end


    // =========================================================
    // EMPTY REGISTER
    // =========================================================

    always_ff @(posedge rd_clk or negedge rst_n) begin

        if (!rst_n)
            empty <= 1'b1;

        else
            empty <= empty_next;

    end


    // =========================================================
    // FULL DETECTION
    //
    // For a Gray-coded asynchronous FIFO:
    //
    // Full occurs when the NEXT write pointer equals
    // the synchronized read pointer with the upper
    // two Gray bits inverted.
    //
    // PTR_WIDTH = ADDR_WIDTH + 1
    // =========================================================

    always_comb begin

        full_next =
            (wr_ptr_gray_next ==
             {
                 ~rd_ptr_gray_sync2[PTR_WIDTH-1:
                                     PTR_WIDTH-2],

                  rd_ptr_gray_sync2[PTR_WIDTH-3:0]
             });

    end


    // =========================================================
    // FULL REGISTER
    // =========================================================

    always_ff @(posedge wr_clk or negedge rst_n) begin

        if (!rst_n)
            full <= 1'b0;

        else
            full <= full_next;

    end


endmodule
