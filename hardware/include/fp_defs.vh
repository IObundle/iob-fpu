// Function width
`define FUNCT_W 4

//
// Function decoder
//
`define FPU_ADD       (`FUNCT_W'd0)
`define FPU_SUB       (`FUNCT_W'd1)
`define FPU_MUL       (`FUNCT_W'd2)
`define FPU_DIV       (`FUNCT_W'd3)
`define FPU_MADD      (`FUNCT_W'd4)
`define FPU_MSUB      (`FUNCT_W'd5)
`define FPU_NMADD     (`FUNCT_W'd6)
`define FPU_NMSUB     (`FUNCT_W'd7)
`define FPU_SQRT      (`FUNCT_W'd8)
`define FPU_MIN_MAX   (`FUNCT_W'd9)
`define FPU_CVT_W_X_U (`FUNCT_W'd10)
`define FPU_CVT_W_X   (`FUNCT_W'd11)
`define FPU_CMP       (`FUNCT_W'd12)
`define FPU_CLASS     (`FUNCT_W'd13)
`define FPU_CVT_X_W_U (`FUNCT_W'd14)
`define FPU_CVT_X_W   (`FUNCT_W'd15)

// Canonical NAN
`define NAN {1'b0, {EXP_W{1'b1}}, 1'b1, {(DATA_W-EXP_W-2){1'b0}}}
