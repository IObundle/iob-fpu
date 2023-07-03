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
   localparam COUNT_W = $clog2(END_COUNT+1);

   reg [COUNT_W-1:0] counter;
   assign done = (counter == END_COUNT[COUNT_W-1:0])? 1'b1: 1'b0;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         counter <= END_COUNT[COUNT_W-1:0];
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
   reg [EXP_W-1:0]          A_Exponent_diff_reg;
   reg                      Equal_zero_reg;
   reg                      Do_start;

   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};
         A_Exponent_diff_reg <= 0;
         Equal_zero_reg <= 1'b0;

         Do_start <= 1'b0;
      end else begin
         if(start) begin // This unit is not fully pipelinable, due to the use of int_sqrt, so just register at the start and reuse when needed
            A_sign_reg <= A_sign;
            A_Exponent_reg <= A_Exponent;
            A_Mantissa_reg <= A_Mantissa;
            A_Exponent_diff_reg <= A_Exponent - BIAS;
            Equal_zero_reg <= (A_Exponent == 0) && (op[MAN_W-2:0] == 0);
         end

         Do_start <= start;
      end
   end

   // Squaring
   wire [MAN_W:0]   Temp_Mantissa; // = sqrt(A_Mantissa_reg);
   int_sqrt #(.DATA_W(MAN_W+2),.FRACTIONAL_W(MAN_W))
   int_sqrt (
             .clk   (clk),
             .rst   (rst),

             .start (Do_start),
             .done  (),

             .op    (A_Exponent_diff_reg[0] ? {2'b00,A_Mantissa_reg} : {1'b0,A_Mantissa_reg,1'b0}),
             .res   (Temp_Mantissa)
             );

   // pipeline stage 3
   reg [EXP_W-1:0]  Temp_Exponent_reg;
   reg [MAN_W-2:0]  Temp_Mantissa_reg;

   wire [EXP_W-1:0] Temp_Computed_Exponent = {A_Exponent_diff_reg[EXP_W-1],A_Exponent_diff_reg[EXP_W-1:1]}; // Signed division by 2
   always @(posedge clk) begin
      if (rst) begin
         Temp_Exponent_reg <= {EXP_W{1'b0}};
         Temp_Mantissa_reg <= {(MAN_W-1){1'b0}};
      end else begin

         if(A_sign_reg || Equal_zero_reg) begin
            Temp_Exponent_reg <= 0;
            Temp_Mantissa_reg <= 0;
         end else begin
            Temp_Exponent_reg <= BIAS + Temp_Computed_Exponent;
            Temp_Mantissa_reg <= A_Exponent_diff_reg[0] ? Temp_Mantissa[MAN_W-2:0] : Temp_Mantissa[MAN_W-1:1];
         end
      end
   end

   wire [MAN_W-2:0]         Mantissa = Temp_Mantissa_reg;
   wire [EXP_W-1:0]         Exponent = Temp_Exponent_reg;
   wire                     Sign = 1'b0;

   // pipeline stage 4
   always @(posedge clk) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
      end else begin
         res <= {Sign, Exponent, Mantissa};
      end
   end

   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = A_sign_reg; // Cannot perform sqrt of negative numbers

endmodule
