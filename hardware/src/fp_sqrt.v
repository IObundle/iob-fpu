`timescale 1ns / 1ps

module fp_sqrt #(
                 parameter DATA_W = 32,
                 parameter EXP_W = 8
                )
   (
    input                   clk,
    input                   rst,

    input                   start,
    output                  done,

    input [DATA_W-1:0]      op,

    output                  overflow,
    output                  underflow,
    output                  exception,

    output reg [DATA_W-1:0] res
    );

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   localparam END_COUNT = MAN_W+EXTRA-1+4; // sqrt cycle count (MAN_W+EXTRA-1) + pipeline stages

   reg [$clog2(END_COUNT+1)-1:0] counter;
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
   wire [MAN_W-1:0]         A_Mantissa = {1'b1, op[MAN_W-2:0]};
   wire [EXP_W-1:0]         A_Exponent = op[DATA_W-2 -: EXP_W];
   wire                     A_sign = op[DATA_W-1];

   // pipeline stage 1
   reg                      A_sign_reg;
   reg [EXP_W-1:0]          A_Exponent_reg;
   reg [MAN_W-1:0]          A_Mantissa_reg;

   reg                      done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         done_int <= start;
      end
   end

   // Division
   wire                     Temp_sign = A_sign_reg;
   wire [EXP_W-1:0]         Temp_Exponent = ((A_Exponent_reg - BIAS) >> 1) + BIAS;
   wire [MAN_W+EXTRA-1:0]   Temp_Mantissa; // = sqrt(A_Mantissa_reg);
   int_sqrt # (
               .DATA_W(2*(MAN_W+EXTRA))
               )
   int_sqrt (
             .clk   (clk),
             .rst   (rst),

             .start (start),
             .done  (),

             .op    ({1'b0, A_Mantissa, {(MAN_W+2*EXTRA-1){1'b0}}}),
             .res   (Temp_Mantissa)
             );

   // pipeline stage 2
   reg                      Temp_sign_reg;
   reg [EXP_W-1:0]          Temp_Exponent_reg;
   reg [MAN_W+EXTRA-1:0]    Temp_Mantissa_reg;

   reg                      done_int2;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= {EXP_W{1'b0}};
         Temp_Mantissa_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int2 <= 1'b0;
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= Temp_Mantissa;

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

   wire [MAN_W+EXTRA-1:0]   Mantissa_int = Temp_Mantissa_reg << lzc;
   wire [EXP_W-1:0]         Exponent_int = Temp_Exponent_reg - lzc;

   // pipeline stage 3
   reg                      Temp_sign_reg2;

   reg [EXP_W-1:0]          Exponent_reg;
   reg [MAN_W+EXTRA-1:0]    Mantissa_reg;

   reg                      done_int3;
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
   wire [MAN_W-1:0]         Mantissa_rnd;
   wire [EXP_W-1:0]         Exponent_rnd;
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
   wire [MAN_W-2:0]         Mantissa = Mantissa_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = Exponent_rnd;
   wire                     Sign = Temp_sign_reg2;

   // pipeline stage 4
   always @(posedge clk) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
         //done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Mantissa};
         //done <= done_int2;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
