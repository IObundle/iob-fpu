`timescale 1ns / 1ps

`include "fp_defs.vh"

//`define __FULL_FPU__

module fpu # (
              parameter DATA_W = 32,
              parameter EXP_W = 8
              )
   (
    input                   clk,
    input                   rst,

    // Inputs
    input                   start,
    input [`FUNCT_W-1:0]    funct,

    input [DATA_W-1:0]      rs1,
    input [DATA_W-1:0]      rs2,
    input [DATA_W-1:0]      rs3,

    input [DATA_W-1:0]      rs1_i,

    // Outputs
    output reg [DATA_W-1:0] res,
    output                  done
    );

   reg                              add, sub;
   reg                              mul;
   reg                              div;
   reg                              fsqrt;
   reg                              min_max;
   reg                              cmp;
   reg                              int2float, uint2float;
   reg                              float2int, float2uint;
   reg                              madd, msub, nmadd, nmsub;
   wire                             any_add = |{add, sub};
   wire                             any_mul = mul;
   wire                             any_div = div;
   wire                             any_sqrt = fsqrt;
   wire                             any_min_max = min_max;
   wire                             any_cmp = cmp;
   wire                             any_int2float = int2float;
   wire                             any_uint2float = uint2float;
   wire                             any_float2int = float2int;
   wire                             any_float2uint = float2uint;
   wire                             any_madd = |{madd, msub, nmadd, nmsub};
   reg                              any_add_reg, any_mul_reg, any_div_reg, any_sqrt_reg, any_min_max_reg, any_cmp_reg, any_int2float_reg, any_uint2float_reg, any_float2int_reg, any_float2uint_reg;

   wire [DATA_W-1:0]                add_res;
   wire [DATA_W-1:0]                mul_res;
   wire [DATA_W-1:0]                div_res;
   wire [DATA_W-1:0]                sqrt_res;
   wire [DATA_W-1:0]                min_max_res;
   wire                             cmp_res;
   wire [DATA_W-1:0]                int2float_res;
   wire [DATA_W-1:0]                uint2float_res;
   wire [DATA_W-1:0]                float2int_res;
   wire [DATA_W-1:0]                float2uint_res;

   wire                             add_done, mul_done, div_done, sqrt_done, min_max_done, cmp_done, int2float_done, uint2float_done, float2int_done, float2uint_done;
   reg                              done_int;
   reg                              done_reg;

   reg                              ready_reg;

   wire                             add_start = any_add & ~(any_add_reg & ~ready_reg);
   wire                             mul_start = any_mul & ~(any_mul_reg & ~ready_reg);
   wire                             div_start = any_div & ~(any_div_reg & ~ready_reg);
   wire                             sqrt_start = any_sqrt & ~(any_sqrt_reg & ~ready_reg);
   wire                             min_max_start = any_min_max & ~(any_min_max_reg & ~ready_reg);
   wire                             cmp_start = any_cmp & ~(any_cmp_reg & ~ready_reg);
   wire                             int2float_start = any_int2float & ~(any_int2float_reg & ~ready_reg);
   wire                             uint2float_start = any_uint2float & ~(any_uint2float_reg & ~ready_reg);
   wire                             float2int_start = any_float2int & ~(any_float2int_reg & ~ready_reg);
   wire                             float2uint_start = any_float2uint & ~(any_float2uint_reg & ~ready_reg);
   wire                             start_int = |{add_start, mul_start, div_start, sqrt_start, min_max_start, cmp_start, int2float_start, uint2float_start, float2int_start, float2uint_start};

   wire                             fpu_wait = start_int | ~done;
   wire                             ready = done & ~done_reg;

   always @* begin
      add = 0;
      sub = 0;
      mul = 0;
      div = 0;
      madd = 0;
      msub = 0;
      nmadd = 0;
      nmsub = 0;
      fsqrt = 0;
      min_max = 0;
      int2float = 0;
      uint2float = 0;
      cmp = 0;
      //fclass = 0;
      float2int = 0;
      float2uint = 0;

      if (start) begin
         case (funct)
           `FPU_ADD: add = 1;
           `FPU_SUB: sub = 1;
           `FPU_MUL: mul = 1;
           `FPU_DIV: div = 1;
`ifdef __FULL_FPU__
           `FPU_MADD: madd = 1;
           `FPU_MSUB: msub = 1;
           `FPU_NMADD: nmadd = 1;
           `FPU_NMSUB: nmsub = 1;
           `FPU_SQRT: fsqrt = 1;
           `FPU_MIN_MAX: min_max = 1;
           `FPU_CVT_W_X_U: float2uint = 1;
           `FPU_CVT_W_X: float2int = 1;
           `FPU_CMP: cmp = 1;
           //`FPU_CLASS: fclass = 1;
           `FPU_CVT_X_W_U: uint2float = 1;
           `FPU_CVT_X_W: int2float = 1;
`endif
         endcase
      end
   end

   always @(posedge clk) begin
      if (rst) begin
         any_add_reg <= 1'b0;
         any_mul_reg <= 1'b0;
         any_div_reg <= 1'b0;
         any_sqrt_reg <= 1'b0;
         any_min_max_reg <= 1'b0;
         any_cmp_reg <= 1'b0;
         any_int2float_reg <= 1'b0;
         any_uint2float_reg <= 1'b0;
         any_float2int_reg <= 1'b0;
         any_float2uint_reg <= 1'b0;
      end else begin
         any_add_reg <= any_add;
         any_mul_reg <= any_mul;
         any_div_reg <= any_div;
         any_sqrt_reg <= any_sqrt;
         any_min_max_reg <= any_min_max;
         any_cmp_reg <= any_cmp;
         any_int2float_reg <= any_int2float;
         any_uint2float_reg <= any_uint2float;
         any_float2int_reg <= any_float2int;
         any_float2uint_reg <= any_float2uint;
      end
   end

   always @ (posedge clk) begin
      if (rst) begin
         ready_reg <= 1'b0;
      end else begin
         ready_reg <= ready;
      end
   end

   always @(posedge clk) begin
      if (rst) begin
         done_reg <= 1'b1;
      end else begin
         done_reg <= done;
      end
   end

   wire [DATA_W-1:0] op_a_add = any_madd? mul_res: rs1;
   wire [DATA_W-1:0] op_b_add_int = any_madd? rs3: rs2;
   wire [DATA_W-1:0] op_b_add = sub? {~op_b_add_int[DATA_W-1], op_b_add_int[DATA_W-2:0]}: op_b_add_int;

   fp_add fp_add0
     (
      .clk(clk),
      .rst(rst),

      .start(add_start),
      .done(add_done),

      .op_a(op_a_add),
      .op_b(op_b_add),
      .res(add_res)
      );

   fp_mul fp_mul0
     (
      .clk(clk),
      .rst(rst),

      .start(mul_start),
      .done(mul_done),

      .op_a(rs1),
      .op_b(rs2),
      .res(mul_res)
      );

   fp_div fp_div0
     (
      .clk(clk),
      .rst(rst),

      .start(div_start),
      .done(div_done),

      .op_a(rs1),
      .op_b(rs2),
      .res(div_res)
      );

`ifdef __FULL_FPU__
   fp_sqrt fp_sqrt0
     (
      .clk(clk),
      .rst(rst),

      .start(sqrt_start),
      .done(sqrt_done),

      .op(rs1),
      .res(sqrt_res)
      );

   fp_minmax # (
                 .DATA_W(DATA_W),
                 .EXP_W(EXP_W)
                 )
   fp_minmax0
     (
      .clk(clk),
      .rst(rst),

      .start(min_max_start),
      .done(min_max_done),

      .max_n_min(rm[0]),
      .op_a(rs1),
      .op_b(rs2),
      .res(min_max_res)
      );

   fp_cmp # (
             .DATA_W(DATA_W),
             .EXP_W(EXP_W)
             )
   fp_cmp0
     (
      .clk(clk),
      .rst(rst),

      .start(cmp_start),
      .done(cmp_done),

      .fn(rm[1:0]),
      .op_a(rs1),
      .op_b(rs2),
      .res(cmp_res)
      );

   fp_int2float fp_int2float0
     (
      .clk(clk),
      .rst(rst),

      .start(int2float_start),
      .done(int2float_done),

      .op(rs1_i),
      .res(int2float_res)
      );

   fp_uint2float fp_uint2float0
     (
      .clk(clk),
      .rst(rst),

      .start(uint2float_start),
      .done(uint2float_done),

      .op(rs1_i),
      .res(uint2float_res)
      );

   fp_float2int fp_float2int0
     (
      .clk(clk),
      .rst(rst),

      .start(float2int_start),
      .done(float2int_done),

      .op(rs1),
      .res(float2int_res)
      );

   fp_float2uint fp_float2uint0
     (
      .clk(clk),
      .rst(rst),

      .start(float2uint_start),
      .done(float2uint_done),

      .op(rs1),
      .res(float2uint_res)
      );
`endif

   assign done = start_int? 1'b0: done_int;

   always @* begin
      res = {DATA_W{1'b0}};
      done_int = 1'b1;

      if (any_add) begin
         if (nmadd | nmsub) begin
            res = {~add_res[DATA_W-1], add_res[DATA_W-2:0]};
         end else begin
            res = add_res;
         end

         done_int = add_done;
      end else if (any_mul) begin
         res = mul_res;
         done_int = mul_done;
      end else if (any_div) begin
         res = div_res;
         done_int = div_done;
`ifdef __FULL_FPU__
      end else if (any_sqrt) begin
         res = sqrt_res;
         done_int = sqrt_done;
      end else if (any_min_max) begin
         res = min_max_res;
         done_int = min_max_done;
      end else if (any_cmp) begin
         res = {{(DATA_W-1){1'b0}}, cmp_res};
         done_int = cmp_done;
      end else if (any_int2float) begin
         res = int2float_res;
         done_int = int2float_done;
      end else if (any_uint2float) begin
         res = uint2float_res;
         done_int = uint2float_done;
      end else if (any_float2int) begin
         res = float2int_res;
         done_int = float2int_done;
      end else if (any_float2uint) begin
         res = float2uint_res;
         done_int = float2uint_done;
`endif
      end
   end

endmodule
