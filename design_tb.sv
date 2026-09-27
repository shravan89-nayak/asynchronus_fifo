`timescale 1ns/1ps

module fifo_tb;

    // =========================================================
    // Parameters
    // =========================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH      = (1 << ADDR_WIDTH);


    // =========================================================
    // Testbench signals
    // =========================================================

    logic wr_clk;
    logic rd_clk;
    logic rst_n;

    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  full;

    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  empty;


    // =========================================================
    // DUT
    // =========================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),

        .wr_en(wr_en),
        .wdata(wdata),
        .full(full),

        .rd_en(rd_en),
        .rdata(rdata),
        .empty(empty)
    );


    // =========================================================
    // WRITE CLOCK
    //
    // 10 ns period = 100 MHz
    // =========================================================

    initial begin

        wr_clk = 1'b0;

        forever
            #5 wr_clk = ~wr_clk;

    end


    // =========================================================
    // READ CLOCK
    //
    // 14 ns period ≈ 71.4 MHz
    //
    // Different from write clock intentionally.
    // =========================================================

    initial begin

        rd_clk = 1'b0;

        forever
            #7 rd_clk = ~rd_clk;

    end


    // =========================================================
    // REFERENCE QUEUE
    //
    // This is our golden model.
    //
    // Data written into FIFO goes into this queue.
    //
    // Data read from FIFO must match the front of queue.
    // =========================================================

    logic [DATA_WIDTH-1:0] reference_queue[$];


    // =========================================================
    // RESET
    // =========================================================

    initial begin

        rst_n = 1'b0;

        wr_en = 1'b0;
        rd_en = 1'b0;
        wdata = '0;

        #30;

        rst_n = 1'b1;

        $display("======================================");
        $display("RESET RELEASED");
        $display("======================================");

    end


    // =========================================================
    // WRITE PROCESS
    // =========================================================

    initial begin

        wait(rst_n == 1'b1);

        forever begin

            @(posedge wr_clk);

            // Randomly decide whether to write
            wr_en <= ($urandom_range(0, 3) != 0);

            // Generate random data
            wdata <= $urandom_range(0, 255);

        end

    end


    // =========================================================
    // READ PROCESS
    // =========================================================

    initial begin

        wait(rst_n == 1'b1);

        forever begin

            @(posedge rd_clk);

            // Randomly decide whether to read
            rd_en <= ($urandom_range(0, 2) == 0);

        end

    end


    // =========================================================
    // REFERENCE MODEL - WRITE
    //
    // At every valid write, put data into reference queue.
    // =========================================================

    always @(posedge wr_clk) begin

        if (rst_n) begin

            if (wr_en && !full) begin

                reference_queue.push_back(wdata);

                $display(
                    "[WRITE] time=%0t data=%0h queue_size=%0d",
                    $time,
                    wdata,
                    reference_queue.size()
                );

            end

        end

    end


    // =========================================================
    // REFERENCE MODEL - READ
    //
    // At every valid read, compare FIFO output with
    // expected data.
    // =========================================================

    always @(posedge rd_clk) begin

        if (rst_n) begin

            if (rd_en && !empty) begin

                // Give DUT nonblocking assignment time to update
                #1;

                if (reference_queue.size() == 0) begin

                    $error(
                        "[ERROR] FIFO produced data but reference queue is empty!"
                    );

                end
                else begin

                    logic [DATA_WIDTH-1:0] expected_data;

                    expected_data = reference_queue.pop_front();

                    if (rdata !== expected_data) begin

                        $error(
                            "[ERROR] READ MISMATCH: time=%0t expected=%0h got=%0h",
                            $time,
                            expected_data,
                            rdata
                        );

                    end
                    else begin

                        $display(
                            "[READ ] time=%0t data=%0h queue_size=%0d",
                            $time,
                            rdata,
                            reference_queue.size()
                        );

                    end

                end

            end

        end

    end


    // =========================================================
    // FULL FLAG CHECK
    // =========================================================

    always @(posedge wr_clk) begin

        if (rst_n) begin

            if (reference_queue.size() > DEPTH) begin

                $error(
                    "[ERROR] Reference queue exceeded FIFO depth!"
                );

            end

        end

    end


    // =========================================================
    // EMPTY FLAG INFORMATION
    // =========================================================

    always @(posedge rd_clk) begin

        if (rst_n) begin

            if (empty) begin

                $display(
                    "[INFO ] FIFO EMPTY at time=%0t",
                    $time
                );
            end

        end

    end


    // =========================================================
    // SIMULATION TIMEOUT
    // =========================================================

    initial begin

        #5000;

        $display("");
        $display("======================================");
        $display("SIMULATION FINISHED");
        $display("======================================");

        if (reference_queue.size() == 0) begin

            $display("REFERENCE QUEUE EMPTY");

        end
        else begin

            $display(
                "REMAINING DATA IN QUEUE = %0d",
                reference_queue.size()
            );

        end

        $finish;

    end


endmodule
