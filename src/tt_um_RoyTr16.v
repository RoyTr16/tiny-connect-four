/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_RoyTr16 (
    input  wire [7:0] ui_in,     // Dedicated inputs
    output wire [7:0] uo_out,    // Dedicated outputs
    input  wire [7:0] uio_in,    // IOs: Input path
    output wire [7:0] uio_out,   // IOs: Output path
    output wire [7:0] uio_oe,    // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,       // always 1 when the design is powered, so you can ignore it
    input  wire       clk,       // clock
    input  wire       rst_n      // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in [6:3], 1'b0};

  // Synchronize reset signal
  wire clk_in_rst_n_sync;

  // VGA output wires
  wire       hsync, vsync;
  wire [1:0] red, green, blue;

  // Buzzer
  wire buzzer_out;

  // Buttons
  wire move_right;
  wire move_left;
  wire drop_piece;

  // Debounced buttons
  wire move_right_debounced;
  wire move_left_debounced;
  wire drop_piece_debounced;

  // Debug
  wire [2:0] current_col;
  wire e_debug;
  wire [1:0] winner;
  wire [1:0] d_piece_data;
  wire read_board;
  wire [2:0] d_r_row;
  wire [2:0] d_r_col;
  wire [7:0] d_uio_in;
  wire [7:0] d_uio_out;
  wire [7:0] d_uio_oe;

  assign uo_out [0] = red   [1];
  assign uo_out [1] = green [1];
  assign uo_out [2] = blue  [1];
  assign uo_out [3] = vsync;
  assign uo_out [4] = red   [0];
  assign uo_out [5] = green [0];
  assign uo_out [6] = blue  [0];
  assign uo_out [7] = hsync;

  assign drop_piece = ui_in [0];
  assign move_right = ui_in [1];
  assign move_left  = ui_in [2];

  assign e_debug = ui_in [7];

  assign d_uio_in = uio_in;
  assign uio_out = e_debug ? d_uio_out : {{7{1'b0}}, buzzer_out};
  assign uio_oe = e_debug ? d_uio_oe : 8'b11111111;

  connect_four_top game_inst (
    .clk_25MHz       (clk),
    .rst_n           (clk_in_rst_n_sync),
    .move_right      (move_right_debounced),
    .move_left       (move_left_debounced),
    .drop_piece      (drop_piece_debounced),
    .e_debug         (e_debug),          // Debug enable
    .read_board      (read_board),       // Read board
    .d_r_row         (d_r_row),          // Debug row
    .d_r_col         (d_r_col),          // Debug column
    .vga_hsync       (hsync),            // Horizontal sync
    .vga_vsync       (vsync),            // Vertical sync
    .vga_r           (red),              // 4-bit Red channel
    .vga_g           (green),            // 4-bit Green channel
    .vga_b           (blue),             // 4-bit Blue channel
    .buzzer_out      (buzzer_out),       // Buzzer
    .current_col_out (current_col),      // Current column
    .winner          (winner),           // Winner
    .d_piece_data    (d_piece_data)      // Debug piece data
  );

  btn_debounce #(
    .CLKS_TO_WAIT(22'h3FFFFF),
    .N_BUTTONS(3)
  ) btn_right_debounce_inst (
    .clk      (clk),
    .rst_n    (clk_in_rst_n_sync),
    .e_debug  (e_debug),
    .btns_in   ({move_right, move_left, drop_piece}),
    .btns_out  ({move_right_debounced, move_left_debounced, drop_piece_debounced})
  );

	debug_controller debug_ctrl (
		.clk(clk),
		.rst_n(clk_in_rst_n_sync),
		.e_debug(e_debug),
		.piece_data(d_piece_data),
    .current_col(current_col),
    .winner(winner),
    .d_r_row(d_r_row),
    .d_r_col(d_r_col),
    .read_board(read_board),
    .uio_in(d_uio_in),
    .uio_out(d_uio_out),
    .uio_oe(d_uio_oe)
	);

  pwrup_synchronizer pwrup_sync_inst (
      .clk_in(clk),
      .rst_n(rst_n),
      .clk_in_rst_n_sync(clk_in_rst_n_sync)
  );

endmodule
