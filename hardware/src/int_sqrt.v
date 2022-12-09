`timescale 1ns / 1ps

module int_sqrt #(
                  parameter DATA_W = 32, // Multiple of two
                  parameter FRACTIONAL_W = 0, // Multiple of two
                  // Do not change this parameters
                  parameter REAL_W = DATA_W - FRACTIONAL_W,
                  parameter SIZE_W = (REAL_W / 2) + FRACTIONAL_W
                  )
  (
   input               clk,
   input               rst,

   input               start,
   output              done,

   input [DATA_W-1:0]  op,

   output [SIZE_W-1:0] res
   );

   localparam END_COUNT = (DATA_W + FRACTIONAL_W) >> 1;
   localparam COUNT_W = $clog2(END_COUNT);

   reg [COUNT_W:0] counter;

   reg                       pc;

   reg [SIZE_W-1:0]          q;
   reg [SIZE_W+1:0]          r;

   reg [DATA_W-1:0]          a;
   wire [SIZE_W+1:0]         right = {q, r[SIZE_W+1], 1'b1};
   wire [SIZE_W+1:0]         left = {r[SIZE_W-1:0], a[DATA_W-1 -: 2]};
   wire [DATA_W-1:0]         a_in = {a[DATA_W-3:0], 2'b00}; // left shift by 2 bits

   wire [SIZE_W+1:0]         tmp = r[SIZE_W+1]? left + right: // add if r is negative
                                                left - right; // subtract if r is positive

   always @(posedge clk) begin
      if (rst) begin
         pc <= 1'd0;
      end else begin
         pc <= pc + 1'b1;

         case (pc)
           0: begin
              if (start) begin
                 a <= op;
                 q <= 0;
                 r <= 0;

                 counter <= 0;
              end else begin
                 pc <= pc;
              end
           end
           1: begin
              r <= tmp;
              q <= {q[SIZE_W-2:0], ~tmp[SIZE_W+1]};

              a <= a_in;

              if (counter != END_COUNT[COUNT_W:0] - 1) begin
                 counter <= counter + 1'b1;
                 pc <= pc;
              end else begin
                 pc <= 1'b0;
              end
           end
           default:;
         endcase
      end
   end

   assign res = q;
   assign done = ~pc;

endmodule
