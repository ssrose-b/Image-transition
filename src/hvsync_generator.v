`default_nettype none
// 640x480 VGA: 800 clocks per line, 525 lines per frame.
module hvsync_generator (
    input wire clk, reset,
    output wire hsync, vsync, display_on,
    output reg [9:0] hpos, vpos
);
    always @(posedge clk) begin
        if (reset) begin
            hpos <= 0;
            vpos <= 0;
        end else if (hpos == 799) begin
            hpos <= 0;
            if (vpos == 524) vpos <= 0;
            else vpos <= vpos + 1'b1;
        end else hpos <= hpos + 1'b1;
    end
    assign hsync = !(hpos >= 656 && hpos < 752);
    assign vsync = !(vpos >= 490 && vpos < 492);
    assign display_on = hpos < 640 && vpos < 480;
endmodule
`default_nettype wire
