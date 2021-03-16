`timescale 1ns / 1ps

module fp_add
   (
    input             clk,
    input             rst,

    input             start,
    output reg        done,

    input [31:0]      op_a,
    input [31:0]      op_b,

    output            overflow,
    output            underflow,
    output            exception,

    output reg [31:0] res
    );

   // Unpack
   wire               comp = (op_a[30:23] >= op_b[30:23])? 1'b1 : 1'b0;

   wire [23:0]        A_Mantissa = comp? {1'b1, op_a[22:0]} : {1'b1, op_b[22:0]};
   wire [7:0]         A_Exponent = comp? op_a[30:23] : op_b[30:23];
   wire               A_sign = comp? op_a[31] : op_b[31];

   wire [23:0]        B_Mantissa = comp? {1'b1, op_b[22:0]} : {1'b1, op_a[22:0]};
   wire [7:0]         B_Exponent = comp? op_b[30:23] : op_a[30:23];
   wire               B_sign = comp? op_b[31] : op_a[31];

   // pipeline stage 1
   reg                A_sign_reg;
   reg [7:0]          A_Exponent_reg;
   reg [23:0]         A_Mantissa_reg;

   reg                B_sign_reg;
   reg [7:0]          B_Exponent_reg;
   reg [23:0]         B_Mantissa_reg;

   reg                done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= 8'd0;
         A_Mantissa_reg <= 24'd0;

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= 8'd0;
         B_Mantissa_reg <= 24'd0;

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         B_sign_reg <= B_sign;
         B_Exponent_reg <= B_Exponent;
         B_Mantissa_reg <= B_Mantissa;

         done_int <= start;
      end
   end

   // Align significants
   wire [7:0]         diff_Exponent = A_Exponent_reg - B_Exponent_reg;
   wire [99:0]        B_Mantissa_in = {B_Mantissa_reg, 76'd0} >> diff_Exponent;

   // Extra bits
   wire               guard_bit = B_Mantissa_in[75];
   wire               round_bit = B_Mantissa_in[74];
   wire               sticky_bit = |B_Mantissa_in[73:0];

   // pipeline stage 2
   reg                A_sign_reg2;
   reg [7:0]          A_Exponent_reg2;
   reg [23:0]         A_Mantissa_reg2;

   reg                B_sign_reg2;
   reg [23:0]         B_Mantissa_reg2;

   reg                guard_bit_reg;
   reg                round_bit_reg;
   reg                sticky_bit_reg;

   reg                done_int2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg2 <= 1'b0;
         A_Exponent_reg2 <= 8'd0;
         A_Mantissa_reg2 <= 24'd0;

         B_sign_reg2 <= 1'b0;
         B_Mantissa_reg2 <= 24'd0;

         guard_bit_reg <= 1'b0;
         round_bit_reg <= 1'b0;
         sticky_bit_reg <= 1'b0;

         done_int2 <= 1'b0;
      end else begin
         A_sign_reg2 <= A_sign_reg;
         A_Exponent_reg2 <= A_Exponent_reg;
         A_Mantissa_reg2 <= A_Mantissa_reg;

         B_sign_reg2 <= B_sign_reg;
         B_Mantissa_reg2 <= B_Mantissa_in[76 +: 24];

         guard_bit_reg <= guard_bit;
         round_bit_reg <= round_bit;
         sticky_bit_reg <= sticky_bit;

         done_int2 <= done_int;
      end
   end

   // Addition
   wire [24:0]        Temp = (A_sign_reg2 ~^ B_sign_reg2)? A_Mantissa_reg2 + B_Mantissa_reg2:
                                                           A_Mantissa_reg2 - B_Mantissa_reg2;
   wire               carry = Temp[24];

   // pipeline stage 3
   reg                A_sign_reg3;
   reg [7:0]          A_Exponent_reg3;

   reg [26:0]         Temp_reg;
   reg                carry_reg;

   reg                done_int3;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg3 <= 1'b0;
         A_Exponent_reg3 <= 8'd0;

         Temp_reg <= 27'd0;
         carry_reg <= 1'b0;

         done_int3 <= 1'b0;
      end else begin
         A_sign_reg3 <= A_sign_reg2;
         A_Exponent_reg3 <= A_Exponent_reg2;

         Temp_reg <= {Temp[23:0], guard_bit_reg, round_bit_reg, sticky_bit_reg};
         carry_reg <= carry;

         done_int3 <= done_int2;
      end
   end

   // Normalize
   wire [4:0] lzc;
   clz #(
         .DATA_W(27)
         )
   clz0
     (
      .data_in  (Temp_reg),
      .data_out (lzc)
      );

   wire [26:0]        Temp_Mantissa = carry_reg? {1'b1, Temp_reg[26:1]} : Temp_reg << lzc;
   wire [7:0]         exp_adjust = carry_reg? A_Exponent_reg3 + 1'b1 : A_Exponent_reg3 - lzc;

   // pipeline stage 4
   reg                A_sign_reg4;

   reg [7:0]          exp_adjust_reg;
   reg [26:0]         Temp_Mantissa_reg;

   reg                done_int4;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg4 <= 1'b0;

         exp_adjust_reg <= 8'd0;
         Temp_Mantissa_reg <= 27'd0;

         done_int4 <= 1'b0;
      end else begin
         A_sign_reg4 <= A_sign_reg3;

         exp_adjust_reg <= exp_adjust;
         Temp_Mantissa_reg <= {Temp_Mantissa[26:1], Temp_Mantissa[0] | Temp_reg[0]};

         done_int4 <= done_int3;
      end
   end

   // Round
   wire [23:0]        Temp_Mantissa_rnd;
   wire [7:0]         exp_adjust_rnd;
   round #(
           .DATA_W (24),
           .EXP_W  (8)
           )
   round0
     (
      .exponent     (exp_adjust_reg),
      .mantissa     (Temp_Mantissa_reg),

      .exponent_rnd (exp_adjust_rnd),
      .mantissa_rnd (Temp_Mantissa_rnd)
      );

   // Pack
   wire [22:0]        Mantissa = Temp_Mantissa_rnd[22:0];
   wire [7:0]         Exponent = exp_adjust_rnd;
   wire               Sign = A_sign_reg4;

   // pipeline stage 5
   always @(posedge clk) begin
      if (rst) begin
         res <= 32'd0;
         done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Mantissa};
         done <= done_int4;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
