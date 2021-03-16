`timescale 1ns / 1ps

// Round to nearest, tie even (3 bits)

module round #(
               parameter DATA_W = 24,
               parameter EXP_W = 8
               )
  (
   input [EXP_W-1:0]    exponent,
   input [DATA_W+3-1:0] mantissa,

   output [EXP_W-1:0]   exponent_rnd,
   output [DATA_W-1:0]  mantissa_rnd
   );

   // Round
   wire                 round = ~mantissa[2]? 1'b0:
                                ~|mantissa[1:0] & ~mantissa[3]? 1'b0: 1'b1;

   wire [DATA_W-1:0]    mantissa_rnd_int = round? mantissa[DATA_W+3-1:3] + 1'b1: mantissa[DATA_W+3-1:3];

   // Normalize
   wire [$clog2(DATA_W)-1:0] lzc;
   clz #(
         .DATA_W(DATA_W)
         )
   clz0
     (
      .data_in  (mantissa_rnd_int),
      .data_out (lzc)
      );

   assign mantissa_rnd = mantissa_rnd_int << lzc;
   assign exponent_rnd = exponent - lzc;

endmodule
