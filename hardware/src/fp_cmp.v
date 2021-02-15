`timescale 1ns / 1ps

module fp_cmp # (
                 parameter DATA_W = 32,
                 parameter EXP_W = 8
                 )
  (
   input              clk,
   input              rst,

   input              start,
   output reg         done,

   input [1:0]        fn,
   input [DATA_W-1:0] op_a,
   input [DATA_W-1:0] op_b,

   output reg         res
   );

   wire               equal = (op_a == op_b)? 1'b1: 1'b0;

   wire               less = (op_a[DATA_W-1] ^ op_b[DATA_W-1])? (op_a[DATA_W-1]? 1'b1: 1'b0):
                                                op_a[DATA_W-1]? ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? 1'b1: 1'b0):
                                                                ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? 1'b0: 1'b1);

   wire               op_a_nan = &op_a[DATA_W-2 -: EXP_W] & |op_a[DATA_W-EXP_W-2:0];
   wire               op_b_nan = &op_b[DATA_W-2 -: EXP_W] & |op_b[DATA_W-EXP_W-2:0];

   wire               res_int = (op_a_nan | op_b_nan)? 1'b0:
                                                fn[1]? equal:
                                                fn[0]? less:
                                                       less|equal;

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res <= 1'b0;
         done <= 1'b0;
      end else begin
         res <= res_int;
         done <= start;
      end
   end

endmodule
