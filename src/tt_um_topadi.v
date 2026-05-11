/*
 * Copyright (c) 2024 Uri Shaked
 * Planetary Analog Clock with 12-Hour Markers
 * Optimized for Tiny Tapeout (< 1500 GE)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_topadi(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path
  input  wire       ena,      // always 1 when powered
  input  wire       clk,      // clock (25.2 MHz)
  input  wire       rst_n     // reset_n - low to reset
);

  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  // VGA signals
  wire hsync, vsync, video_active;
  wire [1:0] R, G, B;
  wire [9:0] pix_x, pix_y;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // ------------------------------------------------------------------------
  // 1. Time Counters (Synchronous)
  // ------------------------------------------------------------------------
  reg [24:0] tick_counter;
  reg [5:0]  seconds, minutes;
  reg [4:0]  hours;

  wire sec_tick = (tick_counter == 25199999);

  always @(posedge clk) begin
    if (!rst_n) begin
      tick_counter <= 0;
      seconds <= 0; minutes <= 0; hours <= 0;
    end else if (sec_tick) begin
      tick_counter <= 0;
      if (seconds == 59) begin
        seconds <= 0;
        if (minutes == 59) begin
          minutes <= 0;
          if (hours == 23) hours <= 0;
          else hours <= hours + 1;
        end else minutes <= minutes + 1;
      end else seconds <= seconds + 1;
    end else begin
      tick_counter <= tick_counter + 1;
    end
  end

  // Base positions
  wire [5:0] h_pos = ((hours % 12) * 5) + (minutes / 12);
  wire [5:0] m_pos = minutes;
  wire [5:0] s_pos = seconds;

  // ------------------------------------------------------------------------
  // 2. Base Vector ROM (Radius = 31, 6-bit signed)
  // ------------------------------------------------------------------------
  function [11:0] get_vec(input [5:0] pos);
    reg signed [5:0] x, y;
    begin
      case(pos)
        0:  begin x = 0;   y = -31; end   1:  begin x = 3;   y = -31; end
        2:  begin x = 6;   y = -30; end   3:  begin x = 10;  y = -29; end
        4:  begin x = 13;  y = -28; end   5:  begin x = 16;  y = -27; end
        6:  begin x = 18;  y = -25; end   7:  begin x = 21;  y = -23; end
        8:  begin x = 23;  y = -21; end   9:  begin x = 25;  y = -18; end
        10: begin x = 27;  y = -16; end   11: begin x = 28;  y = -13; end
        12: begin x = 29;  y = -10; end   13: begin x = 30;  y = -6;  end
        14: begin x = 31;  y = -3;  end   15: begin x = 31;  y = 0;   end
        16: begin x = 31;  y = 3;   end   17: begin x = 30;  y = 6;   end
        18: begin x = 29;  y = 10;  end   19: begin x = 28;  y = 13;  end
        20: begin x = 27;  y = 16;  end   21: begin x = 25;  y = 18;  end
        22: begin x = 23;  y = 21;  end   23: begin x = 21;  y = 23;  end
        24: begin x = 18;  y = 25;  end   25: begin x = 16;  y = 27;  end
        26: begin x = 13;  y = 28;  end   27: begin x = 10;  y = 29;  end
        28: begin x = 6;   y = 30;  end   29: begin x = 3;   y = 31;  end
        30: begin x = 0;   y = 31;  end   31: begin x = -3;  y = 31;  end
        32: begin x = -6;  y = 30;  end   33: begin x = -10; y = 29;  end
        34: begin x = -13; y = 28;  end   35: begin x = -16; y = 27;  end
        36: begin x = -18; y = 25;  end   37: begin x = -21; y = 23;  end
        38: begin x = -23; y = 21;  end   39: begin x = -25; y = 18;  end
        40: begin x = -27; y = 16;  end   41: begin x = -28; y = 13;  end
        42: begin x = -29; y = 10;  end   43: begin x = -30; y = 6;   end
        44: begin x = -31; y = 3;   end   45: begin x = -31; y = 0;   end
        46: begin x = -31; y = -3;  end   47: begin x = -30; y = -6;  end
        48: begin x = -29; y = -10; end   49: begin x = -28; y = -13; end
        50: begin x = -27; y = -16; end   51: begin x = -25; y = -18; end
        52: begin x = -23; y = -21; end   53: begin x = -21; y = -23; end
        54: begin x = -18; y = -25; end   55: begin x = -16; y = -27; end
        56: begin x = -13; y = -28; end   57: begin x = -10; y = -29; end
        58: begin x = -6;  y = -30; end   59: begin x = -3;  y = -31; end
        default: begin x = 0; y = 0; end
      endcase
      get_vec = {y, x};
    end
  endfunction

  // Fetch Vectors
  wire [11:0] H_vec = get_vec(h_pos);
  wire [11:0] M_vec = get_vec(m_pos);
  wire [11:0] S_vec = get_vec(s_pos);

  wire signed [5:0] Hx = H_vec[5:0], Hy = H_vec[11:6];
  wire signed [5:0] Mx = M_vec[5:0], My = M_vec[11:6];
  wire signed [5:0] Sx = S_vec[5:0], Sy = S_vec[11:6];

  // ------------------------------------------------------------------------
  // 3. Orbit Position Calculation (Center = 320, 240)
  // ------------------------------------------------------------------------
  localparam CX = 320;
  localparam CY = 240;

  // Seconds dot (Radius x4 = ~124 pixels)
  wire [9:0] dot_Sx = CX + (Sx <<< 2);
  wire [9:0] dot_Sy = CY + (Sy <<< 2);

  // Minutes dot (Radius x3 = ~93 pixels)
  wire [9:0] dot_Mx = CX + (Mx <<< 1) + Mx;
  wire [9:0] dot_My = CY + (My <<< 1) + My;

  // Hours dot (Radius x2 = ~62 pixels)
  wire [9:0] dot_Hx = CX + (Hx <<< 1);
  wire [9:0] dot_Hy = CY + (Hy <<< 1);

  // ------------------------------------------------------------------------
  // 4. Raster Draw Logic & Symmetrical 12-Hour Markers
  // ------------------------------------------------------------------------
  
  // Absolute distance from center for current pixel
  wire [9:0] abs_dx = (pix_x >= CX) ? (pix_x - CX) : (CX - pix_x);
  wire [9:0] abs_dy = (pix_y >= CY) ? (pix_y - CY) : (CY - pix_y);

  // Downsample to 4x4 blocks by ignoring bottom 2 bits
  wire [7:0] adx = abs_dx[9:2]; 
  wire [7:0] ady = abs_dy[9:2];

  // 12 static markers placed at roughly radius 155 (outside the seconds orbit)
  // Scaled Base Vectors (x5): Pos 0=(0, 155), Pos 5=(80, 135), Pos 10=(135, 80), Pos 15=(155, 0)
  // Divided by 4 for downsampled block coords: 155/4 = 38, 80/4 = 20, 135/4 = 33
  wire is_marker = (adx == 0  && ady == 38) ||  // 12 and 6 o'clock
                   (adx == 38 && ady == 0)  ||  // 3 and 9 o'clock
                   (adx == 20 && ady == 33) ||  // 1, 5, 7, 11 o'clock
                   (adx == 33 && ady == 20);    // 2, 4, 8, 10 o'clock

  // Downsampling equality checks for the orbiting dots
  wire is_sec_dot = (pix_x[9:2] == dot_Sx[9:2]) && (pix_y[9:2] == dot_Sy[9:2]); // 4x4
  wire is_min_dot = (pix_x[9:3] == dot_Mx[9:3]) && (pix_y[9:3] == dot_My[9:3]); // 8x8
  wire is_hr_dot  = (pix_x[9:4] == dot_Hx[9:4]) && (pix_y[9:4] == dot_Hy[9:4]); // 16x16
  wire is_pin     = (pix_x[9:3] == CX[9:3])     && (pix_y[9:3] == CY[9:3]);     // 8x8 Center Pin

  // ------------------------------------------------------------------------
  // 5. RGB Priority Output
  // ------------------------------------------------------------------------
  
  // Colors: Center/Hours = White, Minutes = Yellow/Green, Seconds = Red, Markers = Dark Gray (2'b01)
  wire [1:0] out_R = is_pin ? 2'b11 : is_hr_dot ? 2'b11 : is_sec_dot ? 2'b11 : is_marker ? 2'b01 : 2'b00;
  wire [1:0] out_G = is_pin ? 2'b11 : is_min_dot ? 2'b11 : is_sec_dot ? 2'b00 : is_marker ? 2'b01 : 2'b00;
  wire [1:0] out_B = is_pin ? 2'b11 : is_hr_dot ? 2'b11 : is_sec_dot ? 2'b00 : is_marker ? 2'b01 : 2'b00;

  assign R = video_active ? out_R : 2'b00;
  assign G = video_active ? out_G : 2'b00;
  assign B = video_active ? out_B : 2'b00;

endmodule
