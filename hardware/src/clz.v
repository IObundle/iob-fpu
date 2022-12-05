`timescale 1ns / 1ps

module clz #(
             parameter DATA_W = 32 
             )
  (
   input [DATA_W-1:0]                data_in,
   output reg [$clog2(DATA_W+1)-1:0] data_out
   );

  localparam BIT_W = $clog2(DATA_W+1);

   integer                         i;

   always @* begin
      data_out = DATA_W[BIT_W-1:0];
      for (i=0; i < DATA_W; i=i+1) begin
         if (data_in[i]) begin
            data_out = (DATA_W[BIT_W-1:0] - i[BIT_W-1:0] - 1);
         end
      end
   end

endmodule
