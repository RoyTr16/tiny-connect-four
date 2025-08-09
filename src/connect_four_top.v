module connect_four_top #(ROWS=8, COLS=8) (
	clk_25MHz,
	rst_n,
	move_right,
	move_left,
	drop_piece,
	e_debug,
	read_board,
	d_r_row,
	d_r_col,
	vga_hsync,
	vga_vsync,
	vga_r,
	vga_g,
	vga_b,
	buzzer_out,
	current_col_out,
	winner,
	d_piece_data
);

	input wire clk_25MHz;
	input wire rst_n;
	input wire move_right;
	input wire move_left;
	input wire drop_piece;
	input wire e_debug;
	input wire read_board;
	input wire [2:0] d_r_row;
	input wire [2:0] d_r_col;

	output wire vga_hsync;
	output wire vga_vsync;
	output reg [1:0] vga_r;
	output reg [1:0] vga_g;
	output reg [1:0] vga_b;
	output wire buzzer_out;
	output wire [2:0] current_col_out;
	output wire [1:0] winner;
	output wire [1:0] d_piece_data;

	// VGA params
	localparam H_ACTIVE = 640;
	localparam V_ACTIVE = 480;

	// Board params
	localparam CELL_SIZE = 10'd32;
	localparam BOARD_TOP_LEFT_X = 10'd192;
	localparam BOARD_TOP_LEFT_Y = 10'd112;
	localparam CURSOR_OFFSET = 10'd16;

	// Player definitions
	localparam PLAYER1_COLOR = 2'b01;
	localparam PLAYER2_COLOR = 2'b10;

	// Piece circle params
	localparam CIRCLE_RADIUS = 10'd14;
	localparam CIRCLE_RADIUS_SQUARED = CIRCLE_RADIUS * CIRCLE_RADIUS;

	// VGA colors
	localparam EMPTY_COLOR_R = 2'b01;
	localparam EMPTY_COLOR_G = 2'b11;
	localparam EMPTY_COLOR_B = 2'b01;

	localparam BOARD_COLOR_R = 2'b00;
	localparam BOARD_COLOR_G = 2'b00;
	localparam BOARD_COLOR_B = 2'b11;

	localparam PLAYER1_COLOR_R = 2'b11;
	localparam PLAYER1_COLOR_G = 2'b11;
	localparam PLAYER1_COLOR_B = 2'b00;

	localparam PLAYER2_COLOR_R = 2'b11;
	localparam PLAYER2_COLOR_G = 2'b00;
	localparam PLAYER2_COLOR_B = 2'b00;

	// Winning pieces flashing counter
	localparam FLASH_COUNTER_MAX = 23'h7FFFFF;
	localparam FLASH_COUNTER_BITS = $clog2(FLASH_COUNTER_MAX);

	// Victory and flashing pieces logic
	reg [FLASH_COUNTER_BITS-1:0] flash_counter;
	reg show_winning_pieces;

	// Game state signals
	wire [2:0] current_col;
	wire [1:0] current_player;
	wire game_over;

	// VGA logic ignals
	wire [9:0] h_count;
	wire [9:0] v_count;
	wire draw_board;
	wire draw_cursor;
	wire vga_active;
	wire [1:0] vga_r_data;
	wire [1:0] vga_g_data;
	wire [1:0] vga_b_data;

	// Board data signals
	wire [2:0] col_idx_n;
	wire [2:0] row_idx_n;
	wire [2:0] col_idx;
	wire [2:0] row_idx;
	wire [1:0] piece_color;
	wire winning_piece;
	wire show_piece;
	wire player_1_turn;

	// offset from the top left corner of the board
	wire [9:0] h_count_board_offset;
	wire [9:0] v_count_board_offset;

	// Coordinates of the center of the currently drawn cell and the cursor
	wire [9:0] cell_center_x;
	wire [9:0] cell_center_y;
	wire [9:0] cursor_center_x;
	wire [9:0] cursor_center_y;

	// Distance between the center of the cell and the drawn pixel
	wire [9:0] dx_cell;
	wire [9:0] dy_cell;
	wire [9:0] distance_squared_cell;

	// Distance between the center of the cursor and the drawn pixel
	wire [9:0] dx_cursor;
	wire [9:0] dy_cursor;
	wire [9:0] distance_squared_cursor;

	// Check if the pixel is inside the circle
	wire cell_in_circle;
	// Check if the pixel is inside the circle and the cursor is inside the circle
	wire cursor_in_circle;
	// Draw the cursor circle
	wire draw_circle_cursor;

	// Determine which color to draw
	wire vga_draw_background;
	wire vga_draw_board;
	wire vga_draw_piece_1;
	wire vga_draw_piece_2;

	assign current_col_out = current_col;

	assign h_count_board_offset = h_count - BOARD_TOP_LEFT_X;
	assign v_count_board_offset = v_count - BOARD_TOP_LEFT_Y;

	assign draw_board = (((h_count >= BOARD_TOP_LEFT_X) & (h_count < (BOARD_TOP_LEFT_X + (COLS * CELL_SIZE)))) & (v_count >= BOARD_TOP_LEFT_Y)) & (v_count < (BOARD_TOP_LEFT_Y + (ROWS * CELL_SIZE)));
	assign draw_cursor = ((((h_count >= BOARD_TOP_LEFT_X) & (h_count < (BOARD_TOP_LEFT_X + (COLS * CELL_SIZE)))) & (v_count >= ((BOARD_TOP_LEFT_Y - CURSOR_OFFSET) - CELL_SIZE))) & (v_count < (BOARD_TOP_LEFT_Y - CURSOR_OFFSET))) & (current_col == col_idx);
	assign vga_active = (h_count < H_ACTIVE) & (v_count < V_ACTIVE);
	assign col_idx_n = h_count_board_offset[7:5];
	assign row_idx_n = v_count_board_offset[7:5];
	assign col_idx = (e_debug & read_board)? d_r_col : col_idx_n;
	assign row_idx = (e_debug & read_board)? d_r_row : 3'd7 - row_idx_n;
	assign player_1_turn = current_player == PLAYER1_COLOR;

	assign game_over = (winner != 2'b00);
	assign d_piece_data = piece_color;
	assign show_piece = winning_piece ? show_winning_pieces : 1'b1;

	assign cell_center_x = (BOARD_TOP_LEFT_X + (col_idx * CELL_SIZE)) + (CELL_SIZE / 2);
	assign cell_center_y = (BOARD_TOP_LEFT_Y + (row_idx_n * CELL_SIZE)) + (CELL_SIZE / 2);
	assign cursor_center_x = (BOARD_TOP_LEFT_X + (current_col * CELL_SIZE)) + (CELL_SIZE / 2);
	assign cursor_center_y = (BOARD_TOP_LEFT_Y - CURSOR_OFFSET) - (CELL_SIZE / 2);
	assign dx_cell = h_count - cell_center_x;
	assign dy_cell = v_count - cell_center_y;
	assign distance_squared_cell = (dx_cell * dx_cell) + (dy_cell * dy_cell);
	assign dx_cursor = h_count - cursor_center_x;
	assign dy_cursor = v_count - cursor_center_y;
	assign distance_squared_cursor = (dx_cursor * dx_cursor) + (dy_cursor * dy_cursor);
	assign cell_in_circle = distance_squared_cell <= CIRCLE_RADIUS_SQUARED;
	assign cursor_in_circle = distance_squared_cursor <= CIRCLE_RADIUS_SQUARED;
	assign draw_circle_cursor = (draw_cursor & cursor_in_circle) & ~game_over;

	assign vga_draw_board      = vga_active & draw_board;
	assign vga_draw_background = vga_active & (~draw_board | (draw_board & cell_in_circle));
	assign vga_draw_piece_1    = (vga_draw_board & cell_in_circle & show_piece & (piece_color == PLAYER1_COLOR)) |
	                             (draw_circle_cursor & player_1_turn);
	assign vga_draw_piece_2    = (vga_draw_board & cell_in_circle & show_piece & (piece_color == PLAYER2_COLOR)) |
	                             (draw_circle_cursor & ~player_1_turn);

	// VGA color logic
	assign vga_r_data = vga_draw_piece_1    ? PLAYER1_COLOR_R :
								      vga_draw_piece_2    ? PLAYER2_COLOR_R :
								      vga_draw_background ? EMPTY_COLOR_R   :
								      vga_draw_board      ? BOARD_COLOR_R   :
								      2'b00;
	assign vga_g_data = vga_draw_piece_1    ? PLAYER1_COLOR_G :
								      vga_draw_piece_2    ? PLAYER2_COLOR_G :
								      vga_draw_background ? EMPTY_COLOR_G   :
								      vga_draw_board      ? BOARD_COLOR_G   :
								      2'b00;
	assign vga_b_data = vga_draw_piece_1    ? PLAYER1_COLOR_B :
								      vga_draw_piece_2    ? PLAYER2_COLOR_B :
								      vga_draw_background ? EMPTY_COLOR_B   :
								      vga_draw_board      ? BOARD_COLOR_B   :
								      2'b00;

	// VGA color output
	always @(posedge clk_25MHz or negedge rst_n)
	begin
		if (~rst_n)
		begin
			vga_r <= 2'b00;
			vga_g <= 2'b00;
			vga_b <= 2'b00;
		end
		else
		begin
			vga_r <= vga_r_data;
			vga_g <= vga_g_data;
			vga_b <= vga_b_data;
		end
	end

	// Flashing counter
	always @(posedge clk_25MHz or negedge rst_n)
	begin
		if (~rst_n)
		begin
			flash_counter <= {FLASH_COUNTER_BITS{1'b0}};
			show_winning_pieces <= 1'b1;
		end
		else if (game_over)
		begin
			if (flash_counter == FLASH_COUNTER_MAX)
			begin
				flash_counter <= {FLASH_COUNTER_BITS{1'b0}};
				show_winning_pieces <= ~show_winning_pieces;
			end
			else
				flash_counter <= flash_counter + 1;
		end
	end

	// Generate 25MHz pixel clock
	vga_controller vga_ctrl(
		.pixel_clk(clk_25MHz),
		.rst_n(rst_n),
		.hsync(vga_hsync),
		.vsync(vga_vsync),
		.x_count(h_count),
		.y_count(v_count)
	);

	connect_four game (
		.clk(clk_25MHz),
		.rst_n(rst_n),
		.move_right(move_right),
		.move_left(move_left),
		.drop_piece(drop_piece),
		.top_row_read(row_idx),
		.top_col_read(col_idx),
		.winner(winner),
		.port_current_col(current_col),
		.port_current_player(current_player),
		.top_data_out(piece_color),
		.winning_out(winning_piece),
		.buzzer_out(buzzer_out)
	);

endmodule
