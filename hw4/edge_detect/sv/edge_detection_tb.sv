`timescale 1 ns / 1 ns

module edge_detection_tb;

    localparam string IMG_IN_NAME  = "copper_720_540.bmp";          
    localparam string IMG_OUT_NAME = "output_sobel.bmp";   
    localparam string IMG_CMP_NAME = "stage2_sobel.bmp";  
    
    localparam CLOCK_PERIOD = 10; 
    
    localparam WIDTH = 720;
    localparam HEIGHT = 540;
    localparam BMP_HEADER_SIZE = 54;
    localparam BYTES_PER_PIXEL = 3; 
    localparam BMP_DATA_SIZE = WIDTH * HEIGHT * BYTES_PER_PIXEL;

    logic clock = 1'b1;
    logic reset = '0;
    logic start = '0;
    
    logic        in_full;
    logic        in_wr_en  = '0;
    logic [23:0] in_din    = '0;
    logic        out_empty;
    logic        out_rd_en;
    logic  [7:0] out_dout;

    logic   in_write_done = '0;
    logic   out_read_done = '0;
    integer out_errors    = '0;


    edge_detection_top #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) dut (
        .clock(clock),
        .reset(reset),
        .in_full(in_full),
        .in_wr_en(in_wr_en),
        .in_din(in_din),
        .out_empty(out_empty),
        .out_rd_en(out_rd_en),
        .out_dout(out_dout)
    );


    always begin
        clock = 1'b1;
        #(CLOCK_PERIOD/2);
        clock = 1'b0;
        #(CLOCK_PERIOD/2);
    end

    initial begin : tb_process
        longint unsigned start_time, end_time, duration;
        real fps;

        @(posedge clock);
        reset = 1'b1;
        @(posedge clock);
        reset = 1'b0;

        @(negedge reset);
        @(posedge clock);
        start_time = $time;
        $display("@ %0t: Beginning simulation...", start_time);

        wait(out_read_done);
        end_time = $time;
        duration = end_time - start_time;

        $display("-------------------------------------------------------------");
        $display("@ %0t: Simulation completed.", end_time);
        $display("Total simulation time: %0t ns", duration);
        $display("Total clock cycles:    %0d", duration / CLOCK_PERIOD);
        $display("Total error count:     %0d", out_errors);
        

        fps = 1000000000.0 / duration;
        $display("Throughput:            %0.2f FPS", fps);
        $display("-------------------------------------------------------------");

        $finish;
    end


    initial begin : img_read_process
        int i, r;
        int in_file;
        logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

        @(negedge reset);
        $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);

        in_file = $fopen(IMG_IN_NAME, "rb");
        if (in_file == 0) begin
            $display("Error: Could not open input file %s", IMG_IN_NAME);
            $finish;
        end

        in_wr_en = 1'b0;

        r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

        i = 0;
        while ( i < BMP_DATA_SIZE ) begin
            @(negedge clock);
            in_wr_en = 1'b0;

            if (in_full == 1'b0) begin
                r = $fread(in_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
                in_wr_en = 1'b1;
                i += BYTES_PER_PIXEL;
            end
        end

        @(negedge clock);
        in_wr_en = 1'b0;
        $fclose(in_file);
        $display("@ %0t: Input file read complete.", $time);
        in_write_done = 1'b1;
    end

    initial begin : img_write_process
        int i, r;
        int out_file;
        int cmp_file;
        logic [23:0] cmp_dout; 
        logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

        @(negedge reset);
        @(negedge clock);

        $display("@ %0t: Comparing against reference %s...", $time, IMG_CMP_NAME);
        
        out_file = $fopen(IMG_OUT_NAME, "wb");
        cmp_file = $fopen(IMG_CMP_NAME, "rb");
        
        if (cmp_file == 0) begin
            $display("Error: Could not open reference file %s. Run the C code first!", IMG_CMP_NAME);
            $finish;
        end

        out_rd_en = 1'b0;
        
        r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
        for (i = 0; i < BMP_HEADER_SIZE; i++) begin
            $fwrite(out_file, "%c", bmp_header[i]);
        end

        i = 0;
        while (i < BMP_DATA_SIZE) begin
            @(negedge clock);
            out_rd_en = 1'b0;
            
            if (out_empty == 1'b0) begin

                r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);

                $fwrite(out_file, "%c%c%c", out_dout, out_dout, out_dout);

                if (cmp_dout != {3{out_dout}}) begin
                    if (out_errors < 20) begin 
                        $display("@ %0t: ERROR at byte %0d. Expected %x, Got %x", 
                                 $time, i, cmp_dout, {3{out_dout}});
                    end
                    out_errors += 1;
                end
                
                out_rd_en = 1'b1;
                i += BYTES_PER_PIXEL;
            end
        end

        @(negedge clock);
        out_rd_en = 1'b0;
        $fclose(out_file);
        $fclose(cmp_file);
        out_read_done = 1'b1;
    end

endmodule