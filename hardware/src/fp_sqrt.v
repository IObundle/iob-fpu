`timescale 1ns / 1ps

module fp_sqrt
   (
    input             clk,
    input             rst,

    input             start,
    output            done,

    input [31:0]      op,

    output            overflow,
    output            underflow,
    output            exception,

    output reg [31:0] res
    );

   localparam END_COUNT = 15;

   reg [4:0]     counter;
   assign done = (counter == END_COUNT)? 1'b1: 1'b0;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         counter <= END_COUNT;
      end else if (start) begin
         counter <= 0;
      end else if (~done) begin
         counter <= counter + 1'b1;
      end
   end

   // Unpack
   wire [23:0]        A_Mantissa = {1'b1, op[22:0]};
   wire [7:0]         A_Exponent = op[30:23];
   wire               A_sign = op[31];

   // pipeline stage 1
   reg                A_sign_reg;
   reg [7:0]          A_Exponent_reg;
   reg [23:0]         A_Mantissa_reg;

   reg                done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= 8'd0;
         A_Mantissa_reg <= 24'd0;

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         done_int <= start;
      end
   end

   // Division
   wire               Temp_sign = A_sign_reg;
   wire [7:0]         Temp_Exponent = ((A_Exponent_reg - 127) >> 1) + 127;
   wire [12:0]        Temp_Mantissa; // = sqrt(A_Mantissa_reg);
   int_sqrt # (
               .DATA_W(26)
               )
   int_sqrt (
             .clk   (clk),
             .rst   (rst),

             .start (start),
             .done  (),

             .op    ({1'b0, A_Mantissa, 1'b0}),
             .res   (Temp_Mantissa)
             );

   // pipeline stage 2
   reg                Temp_sign_reg;
   reg [7:0]          Temp_Exponent_reg;
   reg [23:0]         Temp_Mantissa_reg;

   reg                done_int2;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= 8'd0;
         Temp_Mantissa_reg <= 24'd0;

         done_int2 <= 1'b0;
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= {Temp_Mantissa, 11'd0};

         done_int2 <= done_int;
      end
   end

   // Normalize
   wire [4:0] lzc;
   clz #(
         .DATA_W(24)
         )
   clz0
     (
      .data_in  (Temp_Mantissa_reg),
      .data_out (lzc)
      );

   wire [23:0]        Mantissa = Temp_Mantissa_reg << lzc;
   wire [7:0]         Exponent = Temp_Exponent_reg - lzc;
   wire               Sign = Temp_sign_reg;

   // Pack

   // pipeline stage 3
   always @(posedge clk) begin
      if (rst) begin
         res <= 32'd0;
         //done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Mantissa[22:0]};
         //done <= done_int2;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
