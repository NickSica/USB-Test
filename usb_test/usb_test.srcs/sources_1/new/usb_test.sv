`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2019 09:36:12 PM
// Design Name: 
// Module Name: usb_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
typedef enum logic[7:0]
{
    A = 8'h1C,
    B = 8'h32,
    C = 8'h21,
    D = 8'h23,
    E = 8'h24,
    F = 8'h2B,
    G = 8'h34,
    H = 8'h33,
    I = 8'h43,
    J = 8'h3B,
    K = 8'h42,
    L = 8'h4B,
    M = 8'h3A,
    N = 8'h31,
    O = 8'h44,
    P = 8'h4D,
    Q = 8'h15,
    R = 8'h2D,
    S = 8'h1B,
    T = 8'h2C,
    U = 8'h3C,
    V = 8'h2A,
    W = 8'h1D,
    X = 8'h22,
    Y = 8'h35,
    Z = 8'h1A
} usb_codes;

typedef enum logic[2:0]
{
    IDLE_BEGIN  = 3'b000,
    IDLE_COUNT  = 3'b001,
    START       = 3'b010,
    STOP        = 3'b011,
    SEND_CMD    = 3'b100
} handshake_state;

typedef struct packed
{
    logic start;
    logic[7:0] data;
    logic parity;
    logic stop;
} data_word;

module ps2_interface(input logic clk, 
                     inout kbd_clk, kbd_data,
                     output logic[7:0] scancode);
    usb_codes keycodes;
    handshake_state clk_state, kbd_state, state = IDLE_BEGIN;
    data_word word;
    int count = 0, index = 10;
    logic parity = 1'b1, clk_en = 1'b1, data_en = 1'b0, data_out = 1'bz, start_cmd, stop_cmd, send_bit, restart_count;
    logic[10:0] resend_cmd = 11'b0_0111_1111_1_Z;
    
    assign kbd_clk = clk_en ? 1'bz : 1'b0;
    assign kbd_data = data_en ? data_out : 1'bz;
    always_ff @(posedge clk) begin
        if(state == START) begin
            count <= 0;
        end else if(state == IDLE_BEGIN) begin
            count <= 0;
            clk_state <= IDLE_COUNT;
            clk_en <= 1'b1;
            restart_count = 1'b0;
            start_cmd <= 1'b0;
        end else if(state == IDLE_COUNT) begin
            count <= count + 1;
        end else if(state == STOP) begin
            if(parity == word.parity) begin
                clk_state <= IDLE_BEGIN;
                scancode <= {<<{word.data}};
            end else begin
                if(count == 50001) begin
                    clk_state <= SEND_CMD;
                    count <= 0;
                    clk_en <= 1'b1;
                    start_cmd <= 1'b0;
                end else if(count == 50000) begin
                    start_cmd <= 1'b1;
                    clk_en <= 1'b0;
                end else begin
                    start_cmd <= 1'b0;
                    clk_en <= 1'b0;
                    count <= count + 1;
                end
            end
        end
    end
    
    always_ff @(kbd_clk) begin
        if(state == IDLE_COUNT) begin
            restart_count <= 1'b1;
        end        
    end
    
    always_ff @(negedge kbd_clk) begin
        if(count == 25000 && state == IDLE_COUNT) begin
            if(kbd_data == 1'b0) begin
                kbd_state <= START;
            end
        end else if(state == START) begin
            parity <= parity ^ kbd_data;
            word[index] <= kbd_data;
            if(index == 0) begin
                kbd_state <= STOP;
                index <= 11;
            end else begin
                index <= index - 1;
            end
        end else if(state == SEND_CMD) begin
            if(index == 0) begin
                kbd_state <= IDLE_BEGIN;
                index <= 10;
                stop_cmd <= 1'b1;
            end else begin
                send_bit <= resend_cmd[index-1];
                index <= index - 1;
                stop_cmd <= 1'b0;
            end
        end
    end    
    
    always_comb begin
        if(restart_count == 1'b1) begin
            state = IDLE_BEGIN;
        end else if(kbd_state == IDLE_BEGIN) begin
            state = IDLE_BEGIN;
        end else if(kbd_state == STOP) begin
            state = STOP;
        end else if(clk_state == SEND_CMD) begin
            state = SEND_CMD;
        end else if(clk_state == IDLE_BEGIN) begin
            state = IDLE_BEGIN;
        end else if(clk_state == IDLE_COUNT) begin
            state = IDLE_COUNT;
        end else if(kbd_state == START) begin
            state = START;
        end
        
        if(start_cmd == 1'b1) begin
            data_out <= 1'b0;
            data_en <= 1'b1;
        end else if(stop_cmd == 1'b1) begin
            data_en <= 1'b0;
        end else begin
            data_out <= send_bit;
        end
    end
endmodule
