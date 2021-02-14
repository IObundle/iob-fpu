include $(FPU_DIR)/core.mk

# include
INCLUDE+=$(incdir) $(FPU_INC_DIR)

# headers
VHDR+=$(wildcard $(FPU_INC_DIR)/*.vh)

# sources
VSRC+=$(wildcard $(FPU_HW_DIR)/src/*.v)

clean_hw:
	@rm -rf $(FPU_HW_DIR)/fpga/vivado/XCKU $(FPU_HW_DIR)/fpga/quartus/CYCLONEV-GT

.PHONY: clean_hw
