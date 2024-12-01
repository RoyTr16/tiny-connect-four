module victory_checker (
    clk,
    rst_n,
    start,
    move_row,
    move_col,
    data_in,
    row_read,
    col_read,
    done_checking,
    winner
);

    input clk;
    input rst_n;
    input start;
    input [2:0] move_row;
    input [2:0] move_col;
    input [1:0] data_in;

    output [2:0] row_read;
    output [2:0] col_read;
    output reg done_checking;
    output reg [1:0] winner;

    // Victory checking states
	localparam ST_IDLE = 4'b0000;
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

    reg [3:0] check_state;
    reg e_direction_checker;

    wire [1:0] winner_check;

    check_directions check_directions_inst (
		.current_row(move_row),
		.current_col(move_col),
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

    direction_checker direction_checker_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .row(move_row),
        .col(move_col),
        .direction(check_state),
        .data_in(data_in),
        .row_read(row_read),
        .col_read(col_read),
        .winner(winner_check)
    );

    always@(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            winner <= 2'b00;
        end
        else
        begin
            if (winner_check != 2'b00)
            begin
                winner <= winner_check;
            end
        end
    end

	always @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			check_state <= ST_IDLE;
            e_direction_checker <= 1'b0;
            done_checking <= 1'b1;
		end
		else
		begin
            case (check_state)
                ST_IDLE: 
                begin
                    if (start)
                    begin
                        done_checking <= 1'b0;
                        check_state <= ST_CHECKING_DOWN;
                        e_direction_checker <= check_down;
                    end
                end
                ST_CHECKING_DOWN:
                begin
                    check_state <= ST_CHECKING_ROW_1;
                    e_direction_checker <= check_row_1;
                end
                ST_CHECKING_ROW_1:
                begin
                    check_state <= ST_CHECKING_ROW_2;
                    e_direction_checker <= check_row_2;
                end
                ST_CHECKING_ROW_2:
                begin
                    check_state <= ST_CHECKING_ROW_3;
                    e_direction_checker <= check_row_3;
                end
                ST_CHECKING_ROW_3:
                begin
                    check_state <= ST_CHECKING_ROW_4;
                    e_direction_checker <= check_row_4;
                end
                ST_CHECKING_ROW_4:
                begin
                    check_state <= ST_CHECKING_DIAG_RIGHT_UP_1;
                    e_direction_checker <= check_diag_right_up_1;
                end
                ST_CHECKING_DIAG_RIGHT_UP_1:
                begin
                    check_state <= ST_CHECKING_DIAG_RIGHT_UP_2;
                    e_direction_checker <= check_diag_right_up_2;
                end
                ST_CHECKING_DIAG_RIGHT_UP_2:
                begin
                    check_state <= ST_CHECKING_DIAG_RIGHT_UP_3;
                    e_direction_checker <= check_diag_right_up_3;
                end
                ST_CHECKING_DIAG_RIGHT_UP_3:
                begin
                    check_state <= ST_CHECKING_DIAG_RIGHT_UP_4;
                    e_direction_checker <= check_diag_right_up_4;
                end
                ST_CHECKING_DIAG_RIGHT_UP_4:
                begin
                    check_state <= ST_CHECKING_DIAG_LEFT_DOWN_1;
                    e_direction_checker <= check_diag_left_down_1;
                end
                ST_CHECKING_DIAG_LEFT_DOWN_1:
                begin
                    check_state <= ST_CHECKING_DIAG_LEFT_DOWN_2;
                    e_direction_checker <= check_diag_left_down_2;
                end
                ST_CHECKING_DIAG_LEFT_DOWN_2:
                begin
                    check_state <= ST_CHECKING_DIAG_LEFT_DOWN_3;
                    e_direction_checker <= check_diag_left_down_3;
                end
                ST_CHECKING_DIAG_LEFT_DOWN_3:
                begin
                    check_state <= ST_CHECKING_DIAG_LEFT_DOWN_4;
                    e_direction_checker <= check_diag_left_down_4;
                end
                ST_CHECKING_DIAG_LEFT_DOWN_4:
                begin
                    check_state <= ST_CHECKING_DONE;
                    e_direction_checker <= 1'b0;
                end
                ST_CHECKING_DONE:
                begin
                    check_state <= ST_IDLE;
                    done_checking <= 1'b1;
                end
                default:
                    check_state <= ST_IDLE;
            endcase
        end
    end


endmodule
