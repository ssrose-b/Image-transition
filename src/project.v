/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Original author: Uri Shaked
 * Image-loading example modifications: Pongsgon Vichitvejpaisal
 * Adapted for a manually controlled image comparison divider.
 */
`default_nettype none

// Uses the existing hvsync_generator and 320x240 RGB222 .mem files.
module tt_um_vga_example #(
    parameter integer FRAMES_PER_STEP = 1,
    parameter integer STEP_PIXELS = 4
) (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena,
    input wire clk,
    input wire rst_n
);
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    hvsync_generator vga_sync_gen (
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    reg [5:0] img [0:76799];
    reg [5:0] img2 [0:76799];
    initial begin
        $readmemh("../data/bg1_dithering.mem", img);
        $readmemh("../data/bg1.mem", img2);
    end

    // Active-high controls: ui_in[0] = left, ui_in[1] = right.
    // Synchronize switches/buttons to the pixel clock.
    reg [1:0] buttons_meta, buttons_sync;
    always @(posedge clk) begin
        if (!rst_n) begin
            buttons_meta <= 0;
            buttons_sync <= 0;
        end else begin
            buttons_meta <= ui_in[1:0];
            buttons_sync <= buttons_meta;
        end
    end

    // Update between frames. Neither or both buttons pressed = hold.
    // Keep STEP_PIXELS in 1..640 and FRAMES_PER_STEP >= 1.
    reg [9:0] divider_x;
    integer step_count;
    wire frame_tick = (pix_x == 639 && pix_y == 479);

    always @(posedge clk) begin
        if (!rst_n) begin
            divider_x <= 320;
            step_count <= 0;
        end else if (frame_tick) begin
            if (buttons_sync == 2'b01 || buttons_sync == 2'b10) begin
                if (step_count >= FRAMES_PER_STEP - 1) begin
                    step_count <= 0;
                    if (buttons_sync[0]) begin
                        if (divider_x <= STEP_PIXELS)
                            divider_x <= 0;
                        else divider_x <= divider_x - STEP_PIXELS;
                    end else begin
                        if (divider_x >= 640 - STEP_PIXELS)
                            divider_x <= 640;
                        else divider_x <= divider_x + STEP_PIXELS;
                    end
                end else step_count <= step_count + 1;
            end else step_count <= 0;
        end
    end

    wire [16:0] mem_index = (pix_y >> 1) * 17'd320 + (pix_x >> 1);
    reg [5:0] color;
    reg hsync_d, vsync_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            color <= 0;
            hsync_d <= 1;
            vsync_d <= 1;
        end else begin
            // Match sync timing to the one-cycle registered pixel output.
            hsync_d <= hsync;
            vsync_d <= vsync;
            if (video_active && pix_x < 640 && pix_y < 480) begin
                // A two-pixel white divider, hidden at either endpoint.
                if (divider_x > 0 && divider_x < 640 &&
                    (pix_x == divider_x - 1'b1 || pix_x == divider_x))
                    color <= 6'b111111;
                else if (pix_x < divider_x)
                    color <= img[mem_index];   // Dithered, left side
                else
                    color <= img2[mem_index];  // Normal 6-bit, right side
            end else color <= 0;
        end
    end

    wire [1:0] R = color[5:4];
    wire [1:0] G = color[3:2];
    wire [1:0] B = color[1:0];
    assign uo_out = {hsync_d, B[0], G[0], R[0], vsync_d, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
    wire _unused_ok = &{ena, ui_in[7:2], uio_in};
endmodule

`default_nettype wire
