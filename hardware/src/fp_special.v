`timescale 1ns / 1ps

module fp_special #(
                    parameter DATA_W = 32,
                    parameter EXP_W = 8
                    )
   (
    input [DATA_W-1:0] data_in,

    output             nan,
    output             infinite,
    output             zero,
    output             sub_normal
    );

   localparam MAN_W = DATA_W-EXP_W;

   wire                sign = data_in[DATA_W-1];
   wire [EXP_W-1:0]    exponent = data_in[DATA_W-2 -: EXP_W];
   wire [MAN_W-2:0]    mantissa = data_in[MAN_W-2:0];

   wire                exp_all_ones = &exponent;
   wire                exp_zero = ~|exponent;
   wire                man_zero = ~|mantissa;

   assign nan        = exp_all_ones & ~man_zero;
   assign infinite   = exp_all_ones & man_zero;
   assign zero       = exp_zero & man_zero;
   assign sub_normal = exp_zero & ~man_zero;

endmodule
