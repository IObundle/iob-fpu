`timescale 1 ns / 1 ps

module dq # (
             parameter width=8,
             parameter depth=2
             )
  (
   input              clk,
   output [width-1:0] q,
   input [width-1:0]  d
   );

   integer            i;
   reg [width-1:0]    delay_line [depth-1:0];
   always @(posedge clk) begin
      delay_line[0] <= d;
      for (i=1; i < depth; i=i+1) begin
         delay_line[i] <= delay_line[i-1];
      end
   end

   assign q = delay_line[depth-1];

endmodule
