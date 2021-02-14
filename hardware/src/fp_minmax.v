`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_minmax # (
                    parameter DATA_W = 32,
                    parameter EXP_W = 8
                    )
  (
   input                   clk,
   input                   rst,

   input                   start,
   output reg              done,

   input                   max_n_min,
   input [DATA_W-1:0]      op_a,
   input [DATA_W-1:0]      op_b,

   output reg [DATA_W-1:0] res
   );

   wire [DATA_W-1:0]   bigger  = (op_a[DATA_W-1] ^ op_b[DATA_W-1])? (op_a[DATA_W-1]? op_b: op_a):
                                                    op_a[DATA_W-1]? ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? op_b: op_a):
                                                                    ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? op_a: op_b);

   wire [DATA_W-1:0]   smaller = (op_a[DATA_W-1] ^ op_b[DATA_W-1])? (op_a[DATA_W-1]? op_a: op_b):
                                                    op_a[DATA_W-1]? ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? op_a: op_b):
                                                                    ((op_a[DATA_W-2:0] > op_b[DATA_W-2:0])? op_b: op_a);

   wire                op_a_nan = &op_a[DATA_W-2 -: EXP_W] & |op_a[DATA_W-EXP_W-2:0];
   wire                op_b_nan = &op_b[DATA_W-2 -: EXP_W] & |op_b[DATA_W-EXP_W-2:0];

   wire [DATA_W-1:0] res_int = (op_a_nan & op_b_nan)? `NAN:
                                            op_a_nan? op_b:
                                            op_b_nan? op_a:
                                           max_n_min? bigger: smaller;

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
         done <= 1'b0;
      end else begin
         res <= res_int;
         done <= start;
      end
   end

endmodule
