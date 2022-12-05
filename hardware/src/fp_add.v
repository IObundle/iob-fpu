`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_add #(
                parameter DATA_W = 32,
                parameter EXP_W = 8
                )
   (
    input                   clk,
    input                   rst,

    input                   start,
    output reg              done,

    input [DATA_W-1:0]      op_a,
    input [DATA_W-1:0]      op_b,

    output                  overflow,
    output                  underflow,
    output                  exception,

    output reg [DATA_W-1:0] res
    );

   localparam MAN_W = DATA_W-EXP_W; // 24 for EXP_W = 8
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;
   localparam STICKY_BITS = 2*BIAS-1;

   // Special cases
`ifdef SPECIAL_CASES
   wire                     op_a_nan, op_a_inf, op_a_zero, op_a_sub;
   fp_special #(
                .DATA_W(DATA_W),
                .EXP_W(EXP_W)
                )
   special_op_a
     (
      .data_in    (op_a),

      .nan        (op_a_nan),
      .infinite   (op_a_inf),
      .zero       (op_a_zero),
      .sub_normal (op_a_sub)
      );

   wire                     op_b_nan, op_b_inf, op_b_zero, op_b_sub;
   fp_special #(
                .DATA_W(DATA_W),
                .EXP_W(EXP_W)
                )
   special_op_b
     (
      .data_in    (op_b),

      .nan        (op_b_nan),
      .infinite   (op_b_inf),
      .zero       (op_b_zero),
      .sub_normal (op_b_sub)
      );

   wire                     special = op_a_nan | op_a_inf | op_b_nan | op_b_inf;
   wire [DATA_W-1:0]        res_special = (op_a_nan | op_b_nan)? `NAN:
                                          (op_a_inf & op_b_inf)? ((op_a[DATA_W-1] ^ op_b[DATA_W-1])? `NAN:
                                                                                                     `INF(op_a[DATA_W-1])):
                                                       op_b_inf? ((op_a[DATA_W-1] ^ op_b[DATA_W-1])? `INF(~op_b[DATA_W-1]):
                                                                                                     `INF(op_b[DATA_W-1])):
                                                                 `INF(op_a[DATA_W-1]);
`endif

   // Unpack
   wire                     comp = (op_a[DATA_W-2 -: EXP_W] >= op_b[DATA_W-2 -: EXP_W])? 1'b1 : 1'b0;

   wire [MAN_W-1:0]         A_Mantissa = comp? {1'b1, op_a[MAN_W-2:0]} : {1'b1, op_b[MAN_W-2:0]};
   wire [EXP_W-1:0]         A_Exponent = comp? op_a[DATA_W-2 -: EXP_W] : op_b[DATA_W-2 -: EXP_W];
   wire                     A_sign     = comp? op_a[DATA_W-1] : op_b[DATA_W-1];

   wire [MAN_W-1:0]         B_Mantissa = comp? {1'b1, op_b[MAN_W-2:0]} : {1'b1, op_a[MAN_W-2:0]};
   wire [EXP_W-1:0]         B_Exponent = comp? op_b[DATA_W-2 -: EXP_W] : op_a[DATA_W-2 -: EXP_W];
   wire                     B_sign     = comp? op_b[DATA_W-1] : op_a[DATA_W-1];

   // pipeline stage 1
   reg                      A_sign_reg;
   reg [EXP_W-1:0]          A_Exponent_reg;
   reg [MAN_W-1:0]          A_Mantissa_reg;

   reg                      B_sign_reg;
   reg [EXP_W-1:0]          B_Exponent_reg;
   reg [MAN_W-1:0]          B_Mantissa_reg;

   reg                      done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};

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
   wire [EXP_W-1:0]         diff_Exponent = A_Exponent_reg - B_Exponent_reg;
   wire [MAN_W+STICKY_BITS-1:0] B_Mantissa_in = {B_Mantissa_reg, {STICKY_BITS{1'b0}}} >> diff_Exponent;

   // Extra bits
   wire                     guard_bit = B_Mantissa_in[STICKY_BITS-1];
   wire                     round_bit = B_Mantissa_in[STICKY_BITS-2];
   wire                     sticky_bit = |B_Mantissa_in[STICKY_BITS-3:0];

   // pipeline stage 2
   reg                      A_sign_reg2;
   reg [EXP_W-1:0]          A_Exponent_reg2;
   reg [MAN_W-1:0]          A_Mantissa_reg2;

   reg                      B_sign_reg2;
   reg [MAN_W-1:0]          B_Mantissa_reg2;

   reg                      guard_bit_reg;
   reg                      round_bit_reg;
   reg                      sticky_bit_reg;

   reg                      done_int2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg2 <= 1'b0;
         A_Exponent_reg2 <= {EXP_W{1'b0}};
         A_Mantissa_reg2 <= {MAN_W{1'b0}};

         B_sign_reg2 <= 1'b0;
         B_Mantissa_reg2 <= {MAN_W{1'b0}};

         guard_bit_reg <= 1'b0;
         round_bit_reg <= 1'b0;
         sticky_bit_reg <= 1'b0;

         done_int2 <= 1'b0;
      end else begin
         A_sign_reg2 <= A_sign_reg;
         A_Exponent_reg2 <= A_Exponent_reg;
         A_Mantissa_reg2 <= A_Mantissa_reg;

         B_sign_reg2 <= B_sign_reg;
         B_Mantissa_reg2 <= B_Mantissa_in[STICKY_BITS +: MAN_W];

         guard_bit_reg <= guard_bit;
         round_bit_reg <= round_bit;
         sticky_bit_reg <= sticky_bit;

         done_int2 <= done_int;
      end
   end

   // Addition
   wire [MAN_W:0]           Temp = (A_sign_reg2 ^ B_sign_reg2)? A_Mantissa_reg2 - B_Mantissa_reg2:
                                                                A_Mantissa_reg2 + B_Mantissa_reg2;
   wire                     carry = Temp[MAN_W];

   // pipeline stage 3
   reg                      A_sign_reg3;
   reg [EXP_W-1:0]          A_Exponent_reg3;

   reg [MAN_W+EXTRA-1:0]    Temp_reg;
   reg                      carry_reg;

   reg                      done_int3;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg3 <= 1'b0;
         A_Exponent_reg3 <= {EXP_W{1'b0}};

         Temp_reg <= {(MAN_W+EXTRA){1'b0}};
         carry_reg <= 1'b0;

         done_int3 <= 1'b0;
      end else begin
         A_sign_reg3 <= A_sign_reg2;
         A_Exponent_reg3 <= A_Exponent_reg2;

         Temp_reg <= {Temp[MAN_W-1:0], guard_bit_reg, round_bit_reg, sticky_bit_reg};
         carry_reg <= carry;

         done_int3 <= done_int2;
      end
   end

   // Normalize
   wire [$clog2(MAN_W+EXTRA+1)-1:0] lzc;
   clz #(
         .DATA_W(MAN_W+EXTRA)
         )
   clz0
     (
      .data_in  (Temp_reg),
      .data_out (lzc)
      );

   wire [MAN_W+EXTRA-1:0]   Temp_Mantissa = carry_reg? {1'b1, Temp_reg[MAN_W+EXTRA-1:1]} : Temp_reg << lzc;
   wire [EXP_W-1:0]         exp_adjust = carry_reg? A_Exponent_reg3 + 1'b1 : A_Exponent_reg3 - {{EXTRA{1'b0}},lzc};

   // pipeline stage 4
   reg                      A_sign_reg4;

   reg [EXP_W-1:0]          exp_adjust_reg;
   reg [MAN_W+EXTRA-1:0]    Temp_Mantissa_reg;

   reg                      done_int4;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg4 <= 1'b0;

         exp_adjust_reg <= {EXP_W{1'b0}};
         Temp_Mantissa_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int4 <= 1'b0;
      end else begin
         A_sign_reg4 <= A_sign_reg3;

         exp_adjust_reg <= exp_adjust;
         Temp_Mantissa_reg <= {Temp_Mantissa[MAN_W+EXTRA-1:1], Temp_Mantissa[0] | Temp_reg[0]};

         done_int4 <= done_int3;
      end
   end

   // Round
   wire [MAN_W-1:0]         Temp_Mantissa_rnd;
   wire [EXP_W-1:0]         exp_adjust_rnd;
   round #(
           .DATA_W (MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent     (exp_adjust_reg),
      .mantissa     (Temp_Mantissa_reg),

      .exponent_rnd (exp_adjust_rnd),
      .mantissa_rnd (Temp_Mantissa_rnd)
      );

   // Pack
   wire [MAN_W-2:0]         Mantissa = Temp_Mantissa_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = exp_adjust_rnd;
   wire                     Sign = A_sign_reg4;

`ifdef SPECIAL_CASES
   wire [DATA_W-1:0]        res_in  = special? res_special: {Sign, Exponent, Mantissa};
   wire                     done_in = special? start: done_int4;
`else
   wire [DATA_W-1:0]        res_in  = {Sign, Exponent, Mantissa};
   wire                     done_in = done_int4;
`endif

   // pipeline stage 5
   always @(posedge clk) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
         done <= 1'b0;
      end else begin
         res <= res_in;
         done <= done_in;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
