
PROJECT ?= bootloader
BUILD_DIR = ./out
TOOLS_DIR = ../tools
CONFIG_DIR = ../config
SDK_DIR = ../SDK
SRC ?= .
FW_SRC = ../controller/src
SD_HEX = $(SDK)/components/softdevice/s132/hex/s132_nrf52_5.0.0_softdevice.hex
NRFJPROG = nrfjprog
SETTINGSHEX = $(CONFIG_DIR)/settings.hex

#  Compiler/Assembler/Linker Paths
PREFIX = arm-none-eabi-
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
AR = $(PREFIX)ar
SZ = $(PREFIX)size
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S

# Default variables.
BUILD_TYPE ?= Debug

# Configure RTT based on BUILD_TYPE variable.
ifeq "$(BUILD_TYPE)" "Release"
OPTIMIZATION ?= 2
DEFINES += -DNRF_LOG_USES_RTT=0
endif

ifeq "$(BUILD_TYPE)" "Debug"
OPTIMIZATION = 0
DEFINES += -DNRF_LOG_USES_RTT=1
endif

ifneq "$(OS)" "Windows_NT"
COPY=cp
else
COPY=copy
endif

# Create macro which will convert / to \ on Windows.
ifeq "$(OS)" "Windows_NT"
define convert-slash
$(subst /,\,$1)
endef
else
define convert-slash
$1
endef
endif

# Some tools are different on Windows in comparison to Unix.
ifeq "$(OS)" "Windows_NT"
REMOVE = del
SHELL=cmd.exe
REMOVE_DIR = rd /s /q
MKDIR = mkdir
QUIET=>nul 2>nul & exit 0
BLANK_LINE=echo -
else
REMOVE = rm
REMOVE_DIR = rm -r -f
MKDIR = mkdir -p
QUIET=> /dev/null 2>&1 ; exit 0
BLANK_LINE=echo
endif

# Set VERBOSE make variable to 1 to output all tool commands.
VERBOSE?=0
ifeq "$(VERBOSE)" "0"
Q=@
else
Q=
endif

#########################################################################
# List of sources to be compiled/assembled
BOOTLOADER_SRCS = \
main.c \
$(FW_SRC)/twi_mngr.c \
$(FW_SRC)/pca9685.c \
$(CONFIG_DIR)/public_key.c \
$(SRC)/pb/dfu-cc.pb.c \
$(SRC)/pb/dfu_req_handling.c 

SDK_SRCS += \
$(SDK_DIR)/components/libraries/scheduler/app_scheduler.c \
$(SDK_DIR)/components/libraries/timer/app_timer.c \
$(SDK_DIR)/components/libraries/util/app_util_platform.c \
$(SDK_DIR)/components/ble/common/ble_srv_common.c \
$(SDK_DIR)/components/libraries/crc32/crc32.c \
$(SDK_DIR)/components/libraries/mem_manager/mem_manager.c \
$(SDK_DIR)/components/libraries/crypto/backend/micro_ecc/micro_ecc_lib_ecdsa.c \
$(SDK_DIR)/components/libraries/atomic_fifo/nrf_atfifo.c \
$(SDK_DIR)/components/libraries/balloc/nrf_balloc.c \
$(SDK_DIR)/components/libraries/bootloader/ble_dfu/nrf_ble_dfu.c \
$(SDK_DIR)/components/libraries/bootloader/nrf_bootloader.c \
$(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_app_start.c \
$(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_app_start_asm.c \
$(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_info.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_ecdsa.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_hash.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_init.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_keys.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_mem.c \
$(SDK_DIR)/components/libraries/crypto/nrf_crypto_rng.c \
$(SDK_DIR)/components/libraries/crypto/backend/nrf_crypto_sw/nrf_crypto_sw_hash.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_flash.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_handling_error.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_mbr.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_settings.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_settings_svci.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_svci.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_svci_handler.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_transport.c \
$(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_utils.c \
$(SDK_DIR)/components/drivers_nrf/clock/nrf_drv_clock.c \
$(SDK_DIR)/components/drivers_nrf/common/nrf_drv_common.c \
$(SDK_DIR)/components/drivers_nrf/twi_master/nrf_drv_twi.c \
$(SDK_DIR)/external/fprintf/nrf_fprintf.c \
$(SDK_DIR)/external/fprintf/nrf_fprintf_format.c \
$(SDK_DIR)/components/libraries/fstorage/nrf_fstorage.c \
$(SDK_DIR)/components/libraries/fstorage/nrf_fstorage_nvmc.c \
$(SDK_DIR)/components/libraries/fstorage/nrf_fstorage_sd.c \
$(SDK_DIR)/components/libraries/experimental_memobj/nrf_memobj.c \
$(SDK_DIR)/components/drivers_nrf/hal/nrf_nvmc.c \
$(SDK_DIR)/components/softdevice/common/nrf_sdh.c \
$(SDK_DIR)/components/softdevice/common/nrf_sdh_ble.c \
$(SDK_DIR)/components/softdevice/common/nrf_sdh_soc.c \
$(SDK_DIR)/components/libraries/experimental_section_vars/nrf_section_iter.c \
$(SDK_DIR)/components/libraries/strerror/nrf_strerror.c \
$(SDK_DIR)/components/libraries/svc/nrf_svc_handler.c \
$(SDK_DIR)/components/libraries/sha256/sha256.c \
$(SDK_DIR)/components/toolchain/system_nrf52.c \
$(SDK_DIR)/micro-ecc/uECC.c 

LOG_SRCS += \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT.c \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT_printf.c \
$(SDK_DIR)/components/libraries/experimental_log/src/nrf_log_backend_rtt.c \
$(SDK_DIR)/components/libraries/experimental_log/src/nrf_log_backend_serial.c \
$(SDK_DIR)/components/libraries/experimental_log/src/nrf_log_default_backends.c \
$(SDK_DIR)/components/libraries/experimental_log/src/nrf_log_frontend.c \
$(SDK_DIR)/components/libraries/experimental_log/src/nrf_log_str_formatter.c 

PB_SRCS += \
$(SDK_DIR)/external/nano-pb/pb_common.c \
$(SDK_DIR)/external/nano-pb/pb_decode.c \
$(SDK_DIR)/external/nano-pb/pb_encode.c 

CSRCS = \
$(BOOTLOADER_SRCS) \
$(SDK_SRCS) \
$(LOG_SRCS) \
$(PB_SRCS)

ASRCS = $(SDK_DIR)/components/toolchain/gcc/gcc_startup_nrf52.S


#########################################################################
# AS includes
AS_INCLUDES =  \

# C includes
SDK_INCS = \
$(SDK_DIR)/components/boards \
$(SDK_DIR)/components/device \
$(SDK_DIR)/components/softdevice/s132/headers \
$(SDK_DIR)/components/softdevice/s132/headers/nrf52 \
$(SDK_DIR)/components/libraries/scheduler \
$(SDK_DIR)/components/libraries/timer \
$(SDK_DIR)/components/libraries/util \
$(SDK_DIR)/components/ble/common \
$(SDK_DIR)/components/libraries/crc32 \
$(SDK_DIR)/components/libraries/mem_manager \
$(SDK_DIR)/components/libraries/crypto/backend \
$(SDK_DIR)/components/libraries/crypto/backend/micro_ecc \
$(SDK_DIR)/components/libraries/crypto/backend/nrf_crypto_sw \
$(SDK_DIR)/components/libraries/atomic_fifo \
$(SDK_DIR)/components/libraries/balloc \
$(SDK_DIR)/components/libraries/bootloader/ble_dfu \
$(SDK_DIR)/components/libraries/bootloader \
$(SDK_DIR)/components/libraries/crypto \
$(SDK_DIR)/components/libraries/atomic \
$(SDK_DIR)/components/libraries/bootloader/dfu \
$(SDK_DIR)/components/drivers_nrf/clock \
$(SDK_DIR)/components/drivers_nrf/rng \
$(SDK_DIR)/components/drivers_nrf/common \
$(SDK_DIR)/components/drivers_nrf/twi_master \
$(SDK_DIR)/components/drivers_nrf/delay \
$(SDK_DIR)/external/fprintf \
$(SDK_DIR)/components/libraries/fstorage \
$(SDK_DIR)/components/libraries/experimental_memobj \
$(SDK_DIR)/components/libraries/experimental_log \
$(SDK_DIR)/components/libraries/experimental_log/src \
$(SDK_DIR)/components/drivers_nrf/hal \
$(SDK_DIR)/components/softdevice/common \
$(SDK_DIR)/components/libraries/experimental_section_vars \
$(SDK_DIR)/components/libraries/strerror \
$(SDK_DIR)/components/libraries/svc \
$(SDK_DIR)/components/libraries/sha256 \
$(SDK_DIR)/components/toolchain \
$(SDK_DIR)/micro-ecc \
$(SDK_DIR)/components/toolchain \
$(SDK_DIR)/components/toolchain/cmsis/include \
$(SDK_DIR)/external/segger_rtt

INCDIRS = $(FW_SRC)/devices $(SDK_INCS) $(CONFIG_DIR) $(SDK_DIR)/external/nano-pb

#########################################################################
# list of objects

# list of ASM program objects
OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(ASRCS:.S=.o)))
vpath %.S $(sort $(dir $(ASRCS)))
# list of C program objects
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(CSRCS:.c=.o)))
vpath %.c $(sort $(dir $(CSRCS)))


DEVICE_FLAGS=-mcpu=cortex-m4 -mthumb
DEVICE_CFLAGS=$(DEVICE_FLAGS) -mthumb-interwork

# DEFINEs to be used when building C/C++ code
DEFINES += -DNRF52 -DNRF52832_XXAA -DMAIN_APPLICATION_START_ADDR=0x23000 -DNRF_DFU_DEBUG_VERSION
DEFINES += -DSOFTDEVICE_PRESENT -DNRF_SD_BLE_API_VERSION=5 -DS132 -DBOARD_CUSTOM
DEFINES += -DNRF_DFU_SETTINGS_VERSION=1 -DBLE_STACK_SUPPORT_REQD -DNRF52_PAN_74 -DNRF_DFU_SVCI_ENABLED

ifeq "$(OPTIMIZATION)" "0"
DEFINES += -DDEBUG
endif

# Compiler Options
GCFLAGS += -O$(OPTIMIZATION) -g3 $(DEVICE_CFLAGS)
GCFLAGS += -ffunction-sections -fdata-sections  -fno-exceptions -fno-delete-null-pointer-checks
GCFLAGS += $(patsubst %,-I%,$(INCDIRS))
GCFLAGS += $(DEFINES)
GCFLAGS += $(DEPFLAGS)
GCFLAGS += -Wall -Wno-unused-parameter

GPFLAGS += $(GCFLAGS) -std=gnu11

AS_GCFLAGS += -g3 $(DEVICE_FLAGS) -x assembler-with-cpp
AS_GCFLAGS += $(patsubst %,-I%,$(INCDIRS))
AS_FLAGS += -g3 $(DEVICE_FLAGS)

# Linker script to be used.  Indicates what code should be placed where in memory.
LSCRIPT=nrf52boot.ld

# Linker Options.
LDFLAGS = $(DEVICE_FLAGS) --specs=nano.specs -mabi=aapcs
LDFLAGS += -Wl,-Map=$(BUILD_DIR)/$(PROJECT).map,--cref,--gc-sections
LDFLAGS += -T$(LSCRIPT) -L$(SDK_DIR)/components/toolchain/gcc

# Libraries to be linked into final binary
LIBS = -lc -lnosys -lm

#########################################################################
#  Default rules to compile .c and .cpp file to .o
#  and assemble .s files to .o

$(BUILD_DIR)/%.o : %.S Makefile
	@echo Assembling $<
	$(Q) $(MKDIR) $(call convert-slash,$(dir $@)) $(QUIET)
	$(Q) $(CC) $(AS_GCFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o : %.c Makefile
	@echo Compiling $<
	$(Q) $(MKDIR) $(call convert-slash,$(dir $@)) $(QUIET)
	$(Q) $(CC) -c $(GCFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(BUILD_DIR)/%.o : %.s Makefile
	@echo Assembling $<
	$(Q) $(MKDIR) $(call convert-slash,$(dir $@)) $(QUIET)
	$(Q) $(AS) $(AS_FLAGS) -o $@ $<

$(BUILD_DIR)/$(PROJECT).elf : $(OBJECTS) Makefile
	@echo Linking $<
	$(Q) $(CC) $(OBJECTS) $(LDFLAGS) $(LIBS) -o $@
	$(SZ) $@

$(PROJECT).hex: $(BUILD_DIR)/$(PROJECT).elf | $(BUILD_DIR)
	@echo Objcopy $<
	$(HEX) $< $@  

#########################################################################
# default action: build all

all: $(BUILD_DIR)/$(PROJECT).elf $(PROJECT).hex

clean:
	rm -fR .dep $(BUILD_DIR)
	rm $(PROJECT).hex

flash: $(PROJECT).hex
	$(NRFJPROG) -f nrf52 --eraseall
	$(NRFJPROG) -f nrf52 --program $(SD_HEX)
	$(NRFJPROG) -f nrf52 --program $(PROJECT).hex
	$(NRFJPROG) -f nrf52 --program $(SETTINGSHEX)
