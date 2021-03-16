`timescale 1ns / 1ps

module fp_mul
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
   wire [23:0]        A_Mantissa = {1'b1, op_a[22:0]};
   wire [7:0]         A_Exponent = op_a[30:23];
   wire               A_sign = op_a[31];

   wire [23:0]        B_Mantissa = {1'b1, op_b[22:0]};
   wire [7:0]         B_Exponent = op_b[30:23];
   wire               B_sign = op_b[31];

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

   // Multiplication
   wire               Temp_sign = A_sign_reg ^ B_sign_reg;
   wire [7:0]         Temp_Exponent = A_Exponent_reg + B_Exponent_reg - 127;
   wire [47:0]        Temp_Mantissa = A_Mantissa_reg * B_Mantissa_reg;

   // pipeline stage 2
   reg                Temp_sign_reg;
   reg [7:0]          Temp_Exponent_reg;
   reg [27:0]         Temp_Mantissa_reg;

   reg                done_int2;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= 8'd0;
         Temp_Mantissa_reg <= 28'd0;

         done_int2 <= 1'b0;
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= Temp_Mantissa[47 -: 28];

         done_int2 <= done_int;
      end
   end

   // Normalize
   wire [26:0]        Mantissa_int = Temp_Mantissa_reg[27]? Temp_Mantissa_reg[27:1] : Temp_Mantissa_reg[26:0];
   wire [7:0]         Exponent_int = Temp_Mantissa_reg[27]? Temp_Exponent_reg + 1'b1 : Temp_Exponent_reg;

   // pipeline stage 3
   reg                Temp_sign_reg2;

   reg [7:0]          Exponent_reg;
   reg [26:0]         Mantissa_reg;

   reg                done_int3;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg2 <= 1'b0;

         Exponent_reg <= 8'd0;
         Mantissa_reg <= 27'd0;

         done_int3 <= 1'b0;
      end else begin
         Temp_sign_reg2 <= Temp_sign_reg;

         Exponent_reg <= Exponent_int;
         Mantissa_reg <= {Mantissa_int[26:1], Mantissa_int[0] | Temp_Mantissa_reg[0]};

         done_int3 <= done_int2;
      end
   end

   // Round
   wire [23:0]        Mantissa_rnd;
   wire [7:0]         Exponent_rnd;
   round #(
           .DATA_W (24),
           .EXP_W  (8)
           )
   round0
     (
      .exponent     (Exponent_reg),
      .mantissa     (Mantissa_reg),

      .exponent_rnd (Exponent_rnd),
      .mantissa_rnd (Mantissa_rnd)
      );

   // Pack
   wire [22:0]        Mantissa = Mantissa_rnd[22:0];
   wire [7:0]         Exponent = Exponent_rnd;
   wire               Sign = Temp_sign_reg2;

   // pipeline stage 4
   always @(posedge clk) begin
      if (rst) begin
         res <= 32'd0;
         done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Mantissa};
         done <= done_int3;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
