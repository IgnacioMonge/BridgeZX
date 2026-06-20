# BridgeZX - Makefile (sjasmplus)
#
# Targets:
#   make        -> build/brgzx.bin   (normal esxDOS binary)
#   make dot    -> build/brgzx       (dot-command binary)
#   make all    -> both
#   make clean  -> remove build artifacts
#
# Requirements:
#   - sjasmplus in PATH (or set SJASMPLUS=/path/to/sjasmplus)

SJASMPLUS ?= sjasmplus

BUILD_DIR := build
SRC_MAIN  := dot.asm

DEPS := \
  $(SRC_MAIN) \
  boot.asm \
  modules/display.asm \
  modules/ui.asm \
  modules/net.asm \
  modules/crc.asm \
  modules/util.asm \
  modules/esxdos.asm \
  drivers/divmmc.asm

.PHONY: all clean dot

all: $(BUILD_DIR)/brgzx.bin $(BUILD_DIR)/brgzx

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Normal build -> savebin "brgzx.bin"
$(BUILD_DIR)/brgzx.bin: $(DEPS) | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(SJASMPLUS) --nologo --inc=.. ../$(SRC_MAIN)
	@test -f $@ || (echo "ERROR: expected output '$@' not generated."; exit 1)

# DOT build -> define DOT -> savebin "brgzx"
dot: $(BUILD_DIR)/brgzx

$(BUILD_DIR)/brgzx: $(DEPS) | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(SJASMPLUS) --nologo --inc=.. -DDOT ../$(SRC_MAIN)
	@test -f $@ || (echo "ERROR: expected output '$@' not generated."; exit 1)

clean:
	rm -rf $(BUILD_DIR)
