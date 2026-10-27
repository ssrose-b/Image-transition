`timescale 1ns/1ps
module divider_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg [7:0] ui = 0;
    wire [7:0] out;
    tt_um_vga_example dut (
        .ui_in(ui), .uo_out(out), .uio_in(8'b0),
        .uio_out(), .uio_oe(), .ena(1'b1), .clk(clk), .rst_n(rst_n)
    );
    integer i, x, y;
    task check;
        input condition;
        input [511:0] message;
        begin
            if (condition !== 1'b1) $fatal(1, "%0s", message);
        end
    endtask
    task sync_buttons;
        input [1:0] value;
        begin
            @(negedge clk); ui[1:0] = value;
            repeat (3) @(negedge clk);
        end
    endtask
    task advance_frame;
        begin
            @(negedge clk); force dut.frame_tick = 1;
            @(negedge clk); force dut.frame_tick = 0;
        end
    endtask
    initial begin
        force dut.frame_tick = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        check(dut.divider_x == 320, "Reset centers divider");
        for (i = 0; i < 76800; i = i + 1) begin
            check((^dut.img[i]) !== 1'bx, "Dithered memory loaded");
            check((^dut.img2[i]) !== 1'bx, "Normal memory loaded");
        end
        advance_frame;
        check(dut.divider_x == 320, "Idle holds position");
        sync_buttons(2'b01);
        advance_frame;
        check(dut.divider_x == 316, "Input 0 moves left");
        sync_buttons(2'b10);
        advance_frame;
        check(dut.divider_x == 320, "Input 1 moves right");
        sync_buttons(2'b11);
        advance_frame;
        check(dut.divider_x == 320, "Both inputs hold position");
        sync_buttons(2'b01);
        repeat (200) advance_frame;
        check(dut.divider_x == 0, "Left limit clamps at zero");
        sync_buttons(2'b10);
        repeat (200) advance_frame;
        check(dut.divider_x == 640, "Right limit clamps at 640");
        sync_buttons(2'b00);
        @(negedge clk); rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        // Run exactly one complete VGA frame and check output every pixel.
        for (y = 0; y < 525; y = y + 1) begin
            for (x = 0; x < 800; x = x + 1) begin
                check(dut.pix_x == x && dut.pix_y == y, "VGA position timing");
                @(posedge clk); #1;
                check(out[7] == !(x >= 656 && x < 752), "Horizontal sync");
                check(out[3] == !(y >= 490 && y < 492), "Vertical sync");
                if (x < 640 && y < 480) begin
                    if (x == 319 || x == 320)
                        check(dut.color == 63, "White divider");
                    else if (x < 320)
                        check(dut.color == dut.img[(y/2)*320+x/2], "Dithered left pixels");
                    else
                        check(dut.color == dut.img2[(y/2)*320+x/2], "Normal right pixels");
                end else check(dut.color == 0, "Blanking is black");
                @(negedge clk);
            end
        end
        check(dut.pix_x == 0 && dut.pix_y == 0, "VGA frame wraps");
        $display("PASS: image loading, manual controls, limits, pixel selection, blanking and full-frame VGA timing");
        $finish;
    end
endmodule
