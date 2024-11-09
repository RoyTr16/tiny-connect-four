module connect_four (
	clk,
	rst_n,
	move_right,
	move_left,
	drop_piece,
	port_board_out,
	port_current_col,
	port_current_player,
	port_game_over,
	port_winner
);

	reg _sv2v_0;
	parameter ROWS = 8;
	parameter COLS = 8;
	parameter COL_BITS = 3;
	parameter ROW_BITS = 3;
	parameter LAST_COL = 3'd7;
	parameter LAST_ROW = 3'd7;

	// Inputs
	input clk;
	input rst_n;
	input move_right;
	input move_left;
	input drop_piece;

	// Outputs
	output wire [((ROWS * COLS) * 2) - 1:0] port_board_out;
	output wire [2:0] port_current_col;
	output wire [1:0] port_current_player;
	output wire port_game_over;
	output wire [1:0] port_winner;

	// Player IDs
	localparam EMPTY = 2'b00;
	localparam PLAYER1 = 2'b01;
	localparam PLAYER2 = 2'b10;

	// Main game states
	localparam ST_IDLE = 2'b00;
	localparam ST_ADDING_PIECE = 2'b01;
	localparam ST_CHECKING_VICTORY = 2'b10;
	localparam ST_WIN = 2'b11;

	// Victory checking states
	localparam ST_NOT_CHECKING = 4'b0000;
	localparam ST_CHECKING_DOWN = 4'b0001;
	localparam ST_CHECKING_ROW_1 = 4'b0010;
	localparam ST_CHECKING_ROW_2 = 4'b0011;
	localparam ST_CHECKING_ROW_3 = 4'b0100;
	localparam ST_CHECKING_ROW_4 = 4'b0101;
	localparam ST_CHECKING_DIAG_RIGHT_UP_1 = 4'b0110;
	localparam ST_CHECKING_DIAG_RIGHT_UP_2 = 4'b0111;
	localparam ST_CHECKING_DIAG_RIGHT_UP_3 = 4'b1000;
	localparam ST_CHECKING_DIAG_RIGHT_UP_4 = 4'b1001;
	localparam ST_CHECKING_DIAG_LEFT_DOWN_1 = 4'b1010;
	localparam ST_CHECKING_DIAG_LEFT_DOWN_2 = 4'b1011;
	localparam ST_CHECKING_DIAG_LEFT_DOWN_3 = 4'b1100;
	localparam ST_CHECKING_DIAG_LEFT_DOWN_4 = 4'b1101;
	localparam ST_CHECKING_DONE = 4'b1110;
	localparam ST_VICTORY = 4'b1111;

	// Winning pieces flashing counter
	localparam FLASH_COUNTER_MAX = 24'd12500000;

	// Keep track of the game board
	reg  [((ROWS * COLS) * 2) - 1:0] board_out;
	wire [((ROWS * COLS) * 2) - 1:0] board_vec;
	reg  [1:0] board [0:ROWS - 1][0:COLS - 1];

	// Game state variables
	reg [1:0] current_player;
	wire [ROW_BITS-1:0] current_row;
	reg  [COL_BITS-1:0] current_col;
	reg game_over;
	reg [1:0] winner;
	wire [2:0] next_col_right;
	wire [2:0] next_col_left;
	wire [1:0] next_player;
	wire attempted_drop;
	wire drop_allowed;

	// Synchronizers for input buttons
	reg [2:0] drop_piece_sync;
	reg [2:0] move_right_sync;
	reg [2:0] move_left_sync;
	wire rising_drop_piece;
	wire rising_move_right;
	wire rising_move_left;
	wire move_to_right;
	wire move_to_left;

	// Keep track of the number of pieces in each column
	reg [ROW_BITS:0] column_counters [COLS - 1:0];
	wire [ROW_BITS:0] row_to_drop;

	// State machines
	reg [1:0] current_state;
	reg [3:0] check_state;
	wire [3:0] check_state_next_final;

	// Wires that decide whether to check for winning pieces in a direction
	wire check_down;
	wire check_row_1;
	wire check_row_2;
	wire check_row_3;
	wire check_row_4;
	wire check_diag_right_up_1;
	wire check_diag_right_up_2;
	wire check_diag_right_up_3;
	wire check_diag_right_up_4;
	wire check_diag_left_down_1;
	wire check_diag_left_down_2;
	wire check_diag_left_down_3;
	wire check_diag_left_down_4;

	// Wires that store the result of checking for winning pieces in a direction
	wire result_down;
	wire result_row_1;
	wire result_row_2;
	wire result_row_3;
	wire result_row_4;
	wire result_diag_right_up_1;
	wire result_diag_right_up_2;
	wire result_diag_right_up_3;
	wire result_diag_right_up_4;
	wire result_diag_left_down_1;
	wire result_diag_left_down_2;
	wire result_diag_left_down_3;
	wire result_diag_left_down_4;

	// Wires that check if a player has won in a direction
	wire winning_down;
	wire winning_row_1;
	wire winning_row_2;
	wire winning_row_3;
	wire winning_row_4;
	wire winning_diag_right_up_1;
	wire winning_diag_right_up_2;
	wire winning_diag_right_up_3;
	wire winning_diag_right_up_4;
	wire winning_diag_left_down_1;
	wire winning_diag_left_down_2;
	wire winning_diag_left_down_3;
	wire winning_diag_left_down_4;

	// Assign outputs
	assign port_board_out = board_out;
	assign port_current_col = current_col;
	assign port_current_player = current_player;
	assign port_game_over = game_over;
	assign port_winner = winner;

	assign current_row = row_to_drop[ROW_BITS - 1:0];
	assign next_col_right = (current_col == LAST_COL ? 3'b000 : current_col + 3'b001);
	assign next_col_left = (current_col == 0 ? LAST_COL : current_col - 3'b001);
	assign next_player = (current_player == PLAYER1 ? PLAYER2 : PLAYER1);
	assign attempted_drop = current_state == ST_ADDING_PIECE;
	assign drop_allowed = row_to_drop < ROWS;

	// Input button synchronizers
	assign rising_drop_piece = drop_piece_sync[2] & ~drop_piece_sync[1];
	assign rising_move_right = move_right_sync[2] & ~move_right_sync[1];
	assign rising_move_left  = move_left_sync[2] & ~move_left_sync[1];
	assign move_to_right     = rising_move_right & ~rising_move_left;
	assign move_to_left      = rising_move_left & ~rising_move_right;

	assign row_to_drop = column_counters[current_col];
	assign check_state_next_final = (game_over ? ST_VICTORY : ST_CHECKING_DONE);

	assign winning_down = result_down & check_down;
	assign winning_row_1 = result_row_1 & check_row_1;
	assign winning_row_2 = result_row_2 & check_row_2;
	assign winning_row_3 = result_row_3 & check_row_3;
	assign winning_row_4 = result_row_4 & check_row_4;
	assign winning_diag_right_up_1 = result_diag_right_up_1 & check_diag_right_up_1;
	assign winning_diag_right_up_2 = result_diag_right_up_2 & check_diag_right_up_2;
	assign winning_diag_right_up_3 = result_diag_right_up_3 & check_diag_right_up_3;
	assign winning_diag_right_up_4 = result_diag_right_up_4 & check_diag_right_up_4;
	assign winning_diag_left_down_1 = result_diag_left_down_1 & check_diag_left_down_1;
	assign winning_diag_left_down_2 = result_diag_left_down_2 & check_diag_left_down_2;
	assign winning_diag_left_down_3 = result_diag_left_down_3 & check_diag_left_down_3;
	assign winning_diag_left_down_4 = result_diag_left_down_4 & check_diag_left_down_4;

	check_directions check_directions_inst (
		.current_row(current_row),
		.current_col(current_col),
		.check_down(check_down),
		.check_row_1(check_row_1),
		.check_row_2(check_row_2),
		.check_row_3(check_row_3),
		.check_row_4(check_row_4),
		.check_diag_right_up_1(check_diag_right_up_1),
		.check_diag_right_up_2(check_diag_right_up_2),
		.check_diag_right_up_3(check_diag_right_up_3),
		.check_diag_right_up_4(check_diag_right_up_4),
		.check_diag_left_down_1(check_diag_left_down_1),
		.check_diag_left_down_2(check_diag_left_down_2),
		.check_diag_left_down_3(check_diag_left_down_3),
		.check_diag_left_down_4(check_diag_left_down_4)
	);

	results_directions results_directions_inst (
		.current_row(current_row),
		.current_col(current_col),
		.current_player(current_player),
		.board_vec(board_vec),
		.result_down(result_down),
		.result_row_1(result_row_1),
		.result_row_2(result_row_2),
		.result_row_3(result_row_3),
		.result_row_4(result_row_4),
		.result_diag_right_up_1(result_diag_right_up_1),
		.result_diag_right_up_2(result_diag_right_up_2),
		.result_diag_right_up_3(result_diag_right_up_3),
		.result_diag_right_up_4(result_diag_right_up_4),
		.result_diag_left_down_1(result_diag_left_down_1),
		.result_diag_left_down_2(result_diag_left_down_2),
		.result_diag_left_down_3(result_diag_left_down_3),
		.result_diag_left_down_4(result_diag_left_down_4)
	);

	// Flatten the 2D board array into a 1D vector
  genvar i, j;
  generate
    for (i = 0; i < ROWS; i = i + 1) begin : row_loop
      for (j = 0; j < COLS; j = j + 1) begin : col_loop
        assign board_vec[((i*COLS + j)*2) +: 2] = board[i][j];
      end
    end
  endgenerate

	// Synchronizers to detect rising edge of input from user
	always @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			drop_piece_sync <= 3'b111;
			move_right_sync <= 3'b111;
			move_left_sync  <= 3'b111;
		end
		else
		begin
			drop_piece_sync[2:0] <= {drop_piece_sync[1:0], drop_piece};
			move_right_sync[2:0] <= {move_right_sync[1:0], move_right};
			move_left_sync[2:0]  <= {move_left_sync[1:0], move_left};
		end
	end

	// State Machine to control the game
	always @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)
			current_state <= ST_IDLE;
		else
			case (current_state)
				ST_IDLE:
					if (rising_drop_piece)
						current_state <= ST_ADDING_PIECE;
				ST_ADDING_PIECE:
					if (drop_allowed)
						current_state <= ST_CHECKING_VICTORY;
					else
						current_state <= ST_IDLE;
				ST_CHECKING_VICTORY:
					if (check_state == ST_VICTORY)
						current_state <= ST_WIN;
					else if (check_state == ST_CHECKING_DONE)
						current_state <= ST_IDLE;
					else
						current_state <= ST_CHECKING_VICTORY;
				ST_WIN:
					current_state <= ST_WIN;
			endcase
	end

	// Column to drop the piece
	always @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)
			current_col <= 3'b000;
		else if (current_state == ST_IDLE)
		begin
			if (move_to_right)
				current_col <= next_col_right;
			else if (move_to_left)
				current_col <= next_col_left;
		end
	end

	// Check for victory
	// Based on the drop location, check for a win in the relevant directions
	// Every clock take 4 squares and check if they are the same player
	// Don't perform the check in a direction if it's not possible to win in that direction
	// For example: If the piece is in the first row, don't check up
	// If the piece is in the last column, don't check right
	always @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			game_over <= 1'b0;
			winner <= 2'b00;
			check_state <= ST_NOT_CHECKING;
			current_player <= 2'b01;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < ROWS; i = i + 1)
					column_counters[i] <= 4'b0000;
			end
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < ROWS; i = i + 1)
					begin : sv2v_autoblock_3
						reg signed [31:0] j;
						for (j = 0; j < COLS; j = j + 1)
							begin
								board[i][j] <= 2'b00;
							end
					end
			end
		end
		else if (current_state == ST_ADDING_PIECE)
		begin
			if (attempted_drop)
			begin
				if (drop_allowed)
					board[current_row][current_col] <= current_player;
			end
		end
		else if (current_state == ST_CHECKING_VICTORY)
			case (check_state)
				ST_NOT_CHECKING: check_state <= ST_CHECKING_DOWN;
				ST_CHECKING_DOWN:
				begin
					check_state <= ST_CHECKING_ROW_1;
					if (winning_down)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_ROW_1:
				begin
					check_state <= ST_CHECKING_ROW_2;
					if (winning_row_1)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_ROW_2:
				begin
					check_state <= ST_CHECKING_ROW_3;
					if (winning_row_2)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_ROW_3:
				begin
					check_state <= ST_CHECKING_ROW_4;
					if (winning_row_3)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_ROW_4:
				begin
					check_state <= ST_CHECKING_DIAG_RIGHT_UP_1;
					if (winning_row_4)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_RIGHT_UP_1:
				begin
					check_state <= ST_CHECKING_DIAG_RIGHT_UP_2;
					if (winning_diag_right_up_1)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_RIGHT_UP_2:
				begin
					check_state <= ST_CHECKING_DIAG_RIGHT_UP_3;
					if (winning_diag_right_up_2)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_RIGHT_UP_3:
				begin
					check_state <= ST_CHECKING_DIAG_RIGHT_UP_4;
					if (winning_diag_right_up_3)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_RIGHT_UP_4:
				begin
					check_state <= ST_CHECKING_DIAG_LEFT_DOWN_1;
					if (winning_diag_right_up_4)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_LEFT_DOWN_1:
				begin
					check_state <= ST_CHECKING_DIAG_LEFT_DOWN_2;
					if (winning_diag_left_down_1)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_LEFT_DOWN_2:
				begin
					check_state <= ST_CHECKING_DIAG_LEFT_DOWN_3;
					if (winning_diag_left_down_2)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_LEFT_DOWN_3:
				begin
					check_state <= ST_CHECKING_DIAG_LEFT_DOWN_4;
					if (winning_diag_left_down_3)
					begin
						game_over <= 1'b1;
					end
				end
				ST_CHECKING_DIAG_LEFT_DOWN_4:
				begin
					check_state <= check_state_next_final;
					if (winning_diag_left_down_4)
					begin
						game_over <= 1'b1;
					end
				end
				ST_VICTORY:
				begin
					winner <= current_player;
					check_state <= ST_CHECKING_DONE;
				end
				ST_CHECKING_DONE:
				begin
					check_state <= ST_NOT_CHECKING;
					column_counters[current_col] <= column_counters[current_col] + 3'b001;
					current_player <= next_player;
				end
				default:
					check_state <= ST_NOT_CHECKING;
			endcase
	end


	// Output the board state
	always @(*)
	begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_4
			reg signed [31:0] row;
			for (row = 0; row < ROWS; row = row + 1)
				begin : sv2v_autoblock_5
					reg signed [31:0] col;
					for (col = 0; col < COLS; col = col + 1)
						begin
							board_out[((((ROWS - 1) - row) * COLS) + ((COLS - 1) - col)) * 2+:2] = board[row][col];
						end
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
