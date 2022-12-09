`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_div #(
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

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   localparam END_COUNT = 2*MAN_W+EXTRA+1+4-1; // divider cycle count (2*MAN_W+EXTRA+1) + pipeline stages - 1

   reg [$clog2(END_COUNT+1)-1:0] counter;
   wire                          cnt_done = (counter == END_COUNT)? 1'b1: 1'b0;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         counter <= END_COUNT;
      end else if (start) begin
         counter <= 0;
      end else if (~cnt_done) begin
         counter <= counter + 1'b1;
      end
   end

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

   wire                     special = op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero;
   wire [DATA_W-1:0]        res_special = (op_a_nan | op_b_nan)? `NAN:
                                                       op_b_inf? (op_a_inf? `NAN: {DATA_W{1'b0}}):
                                         (op_a_inf & op_b_zero)? `NAN:
                                        (op_a_zero & op_b_zero)? `NAN:
                                                                 `INF(op_a[DATA_W-1] ^ op_b[DATA_W-1]);
`endif

   // Unpack
   wire [MAN_W-1:0]              A_Mantissa = {1'b1, op_a[MAN_W-2:0]};
   wire [EXP_W-1:0]              A_Exponent = op_a[DATA_W-2 -: EXP_W];
   wire                          A_sign     = op_a[DATA_W-1];

   wire [MAN_W-1:0]              B_Mantissa = {1'b1, op_b[MAN_W-2:0]};
   wire [EXP_W-1:0]              B_Exponent = op_b[DATA_W-2 -: EXP_W];
   wire                          B_sign     = op_b[DATA_W-1];

   // pipeline stage 1
   reg                           A_sign_reg;
   reg [EXP_W-1:0]               A_Exponent_reg;
   reg [MAN_W-1:0]               A_Mantissa_reg;

   reg                           B_sign_reg;
   reg [EXP_W-1:0]               B_Exponent_reg;
   reg [MAN_W-1:0]               B_Mantissa_reg;

   reg                           done_int;
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

   // Division
   wire                          Temp_sign = A_sign_reg ^ B_sign_reg;
   wire [EXP_W-1:0]              Temp_Exponent = A_Exponent_reg - B_Exponent_reg + BIAS;
   wire [2*MAN_W+EXTRA-1:0]      Temp_Mantissa; // = A_Mantissa_reg / B_Mantissa_reg;
   div_subshift # (
                   .DATA_W(2*MAN_W+EXTRA)
                   )
   div_subshift (
                 .clk       (clk),

                 .en        (~start),
                 .sign      (1'b0),
                 .done      (),

                 .dividend  ({1'b0, A_Mantissa, {(MAN_W+EXTRA-1){1'b0}}}),
                 .divisor   ({{(MAN_W+EXTRA){1'b0}}, B_Mantissa}),
                 .quotient  (Temp_Mantissa),
                 .remainder ()
                 );

   // pipeline stage 2
   reg                           Temp_sign_reg;
   reg [EXP_W-1:0]               Temp_Exponent_reg;
   reg [MAN_W+EXTRA-1:0]         Temp_Mantissa_reg;

   reg                           done_int2;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= {EXP_W{1'b0}};
         Temp_Mantissa_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int2 <= 1'b0;
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= Temp_Mantissa[MAN_W+EXTRA-1:0];

         done_int2 <= done_int;
      end
   end

   // Normalize
   wire [$clog2(MAN_W+EXTRA+1)-1:0] lzc;
   clz #(
         .DATA_W(MAN_W+EXTRA)
         )
   clz0
     (
      .data_in  (Temp_Mantissa_reg),
      .data_out (lzc)
      );

   wire [MAN_W+EXTRA-1:0]        Mantissa_int = Temp_Mantissa_reg << lzc;
   wire [EXP_W-1:0]              Exponent_int = Temp_Exponent_reg - {{EXTRA{1'b0}},lzc};

   // pipeline stage 3
   reg                           Temp_sign_reg2;

   reg [EXP_W-1:0]               Exponent_reg;
   reg [MAN_W+EXTRA-1:0]         Mantissa_reg;

   reg                           done_int3;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg2 <= 1'b0;

         Exponent_reg <= {EXP_W{1'b0}};
         Mantissa_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int3 <= 1'b0;
      end else begin
         Temp_sign_reg2 <= Temp_sign_reg;

         Exponent_reg <= Exponent_int;
         Mantissa_reg <= {Mantissa_int[MAN_W+EXTRA-1:1], Temp_Mantissa_reg[0]};

         done_int3 <= done_int2;
      end
   end

   // Round
   wire [MAN_W-1:0]              Mantissa_rnd;
   wire [EXP_W-1:0]              Exponent_rnd;
   round #(
           .DATA_W (MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent     (Exponent_reg),
      .mantissa     (Mantissa_reg),

      .exponent_rnd (Exponent_rnd),
      .mantissa_rnd (Mantissa_rnd)
      );

   // Pack
   wire [MAN_W-2:0]              Mantissa = Mantissa_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]              Exponent = Exponent_rnd;
   wire                          Sign = Temp_sign_reg2;

`ifdef SPECIAL_CASES
   wire [DATA_W-1:0]             res_in  = special? res_special: {Sign, Exponent, Mantissa};
   wire                          done_in = special? start: (~start & cnt_done);
`else
   wire [DATA_W-1:0]             res_in  = {Sign, Exponent, Mantissa};
   wire                          done_in = ~start & cnt_done;
`endif

   // pipeline stage 4
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
