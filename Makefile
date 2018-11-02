
PROJECT ?= bootloader
BUILD_DIR = ./out
TOOLS_DIR = ../tools
CONFIG_DIR = ../config
SDK_DIR = ../SDK15.2
SRC ?= .
FW_SRC = ../controller/src
SD_HEX = $(SDK_DIR)/components/softdevice/s132/hex/s132_nrf52_6.1.0_softdevice.hex
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
VERBOSE?=1
ifeq "$(VERBOSE)" "0"
Q=@
else
Q=
endif

#########################################################################
# List of sources to be compiled/assembled
BOOTLOADER_SRCS = \
main.c \
$(FW_SRC)/pca9685.c \
$(CONFIG_DIR)/public_key.c 

SDK_SRCS += \
  $(SDK_DIR)/modules/nrfx/mdk/system_nrf52.c \
  $(SDK_DIR)/components/libraries/util/app_error_weak.c \
  $(SDK_DIR)/components/libraries/scheduler/app_scheduler.c \
  $(SDK_DIR)/components/libraries/util/app_util_platform.c \
  $(SDK_DIR)/components/libraries/crc32/crc32.c \
  $(SDK_DIR)/components/libraries/mem_manager/mem_manager.c \
  $(SDK_DIR)/components/libraries/util/nrf_assert.c \
  $(SDK_DIR)/components/libraries/atomic_fifo/nrf_atfifo.c \
  $(SDK_DIR)/components/libraries/atomic/nrf_atomic.c \
  $(SDK_DIR)/components/libraries/balloc/nrf_balloc.c \
  $(SDK_DIR)/external/micro-ecc/uECC.c \
  $(SDK_DIR)/external/fprintf/nrf_fprintf.c \
  $(SDK_DIR)/external/fprintf/nrf_fprintf_format.c \
  $(SDK_DIR)/components/libraries/fstorage/nrf_fstorage.c \
  $(SDK_DIR)/components/libraries/fstorage/nrf_fstorage_nvmc.c \
  $(SDK_DIR)/components/libraries/fstorage/nrf_fstorage_sd.c \
  $(SDK_DIR)/components/libraries/memobj/nrf_memobj.c \
  $(SDK_DIR)/components/libraries/queue/nrf_queue.c \
  $(SDK_DIR)/components/libraries/ringbuf/nrf_ringbuf.c \
  $(SDK_DIR)/components/libraries/experimental_section_vars/nrf_section_iter.c \
  $(SDK_DIR)/components/libraries/strerror/nrf_strerror.c \
  $(SDK_DIR)/components/libraries/sha256/sha256.c \
  $(SDK_DIR)/components/libraries/crypto/backend/micro_ecc/micro_ecc_backend_ecc.c \
  $(SDK_DIR)/components/libraries/crypto/backend/micro_ecc/micro_ecc_backend_ecdh.c \
  $(SDK_DIR)/components/libraries/crypto/backend/micro_ecc/micro_ecc_backend_ecdsa.c \
  $(SDK_DIR)/components/boards/boards.c \
  $(SDK_DIR)/modules/nrfx/hal/nrf_nvmc.c \
  $(SDK_DIR)/components/libraries/crypto/nrf_crypto_ecc.c \
  $(SDK_DIR)/components/libraries/crypto/nrf_crypto_ecdsa.c \
  $(SDK_DIR)/components/libraries/crypto/nrf_crypto_hash.c \
  $(SDK_DIR)/components/libraries/crypto/nrf_crypto_init.c \
  $(SDK_DIR)/components/libraries/crypto/nrf_crypto_shared.c \
  $(SDK_DIR)/components/ble/common/ble_srv_common.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_app_start.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_app_start_final.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_dfu_timers.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_fw_activation.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_info.c \
  $(SDK_DIR)/components/libraries/bootloader/nrf_bootloader_wdt.c \
  $(SDK_DIR)/external/nano-pb/pb_common.c \
  $(SDK_DIR)/external/nano-pb/pb_decode.c \
  $(SDK_DIR)/components/libraries/crypto/backend/nrf_sw/nrf_sw_backend_hash.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/dfu-cc.pb.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu.c \
  $(SDK_DIR)/components/libraries/bootloader/ble_dfu/nrf_dfu_ble.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_flash.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_handling_error.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_mbr.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_req_handler.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_settings.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_settings_svci.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_transport.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_utils.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_validation.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_ver_validation.c \
  $(SDK_DIR)/components/libraries/bootloader/dfu/nrf_dfu_svci_handler.c \
  $(SDK_DIR)/components/libraries/svc/nrf_svc_handler.c \
  $(SDK_DIR)/components/softdevice/common/nrf_sdh.c \
  $(SDK_DIR)/components/softdevice/common/nrf_sdh_ble.c \
  $(SDK_DIR)/components/softdevice/common/nrf_sdh_soc.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_chacha_poly_aead.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_ecc.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_ecdh.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_ecdsa.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_eddsa.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_hash.c \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon/oberon_backend_hmac.c \
  $(SDK_DIR)/components/libraries/twi_mngr/nrf_twi_mngr.c \
  $(SDK_DIR)/modules/nrfx/drivers/src/nrfx_twi.c \
  $(SDK_DIR)/modules/nrfx/drivers/src/nrfx_twim.c \
  $(SDK_DIR)/integration/nrfx/legacy/nrf_drv_twi.c \
  $(SDK_DIR)/libraries/util/app_error_handler_gcc.c

LOG_SRCS += \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT.c \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c \
$(SDK_DIR)/external/segger_rtt/SEGGER_RTT_printf.c \
$(SDK_DIR)/components/libraries/log/src/nrf_log_frontend.c \
$(SDK_DIR)/components/libraries/log/src/nrf_log_default_backends.c \
$(SDK_DIR)/components/libraries/log/src/nrf_log_backend_rtt.c \
$(SDK_DIR)/components/libraries/log/src/nrf_log_backend_serial.c \
$(SDK_DIR)/components/libraries/log/src/nrf_log_str_formatter.c \

CSRCS = \
$(BOOTLOADER_SRCS) \
$(SDK_SRCS) \
$(LOG_SRCS) \

ASRCS = $(SDK_DIR)/modules/nrfx/mdk/gcc_startup_nrf52.S


#########################################################################
# AS includes
AS_INCLUDES =  \

# C includes
SDK_INCS = \
  $(SDK_DIR)/components/libraries/crypto/backend/micro_ecc \
  $(SDK_DIR)/components/softdevice/s132/headers \
  $(SDK_DIR)/components/libraries/memobj \
  $(SDK_DIR)/components/libraries/sha256 \
  $(SDK_DIR)/components/libraries/crc32 \
  $(SDK_DIR)/components/libraries/experimental_section_vars \
  $(SDK_DIR)/components/libraries/mem_manager \
  $(SDK_DIR)/components/libraries/fstorage \
  $(SDK_DIR)/components/libraries/util \
  $(SDK_DIR)/modules/nrfx \
  $(SDK_DIR)/external/nrf_oberon/include \
  $(SDK_DIR)/components/libraries/crypto/backend/oberon \
  $(SDK_DIR)/components/libraries/crypto/backend/cifra \
  $(SDK_DIR)/components/libraries/atomic \
  $(SDK_DIR)/integration/nrfx \
  $(SDK_DIR)/components/libraries/crypto/backend/cc310_bl \
  $(SDK_DIR)/components/softdevice/s132/headers/nrf52 \
  $(SDK_DIR)/components/libraries/log/src \
  $(SDK_DIR)/components/libraries/bootloader/dfu \
  $(SDK_DIR)/components/ble/common \
  $(SDK_DIR)/components/libraries/delay \
  $(SDK_DIR)/components/libraries/svc \
  $(SDK_DIR)/components/libraries/stack_info \
  $(SDK_DIR)/components/libraries/crypto/backend/nrf_hw \
  $(SDK_DIR)/components/libraries/log \
  $(SDK_DIR)/components/libraries/twi_mngr \
  $(SDK_DIR)/integration/nrfx/legacy \
  $(SDK_DIR)/external/nrf_oberon \
  $(SDK_DIR)/components/libraries/strerror \
  $(SDK_DIR)/components/libraries/crypto/backend/mbedtls \
  $(SDK_DIR)/components/boards \
  $(SDK_DIR)/components/libraries/crypto/backend/cc310 \
  $(SDK_DIR)/components/libraries/bootloader \
  $(SDK_DIR)/external/fprintf \
  $(SDK_DIR)/components/libraries/crypto \
  $(SDK_DIR)/components/libraries/scheduler \
  $(SDK_DIR)/modules/nrfx/hal \
  $(SDK_DIR)/components/toolchain/cmsis/include \
  $(SDK_DIR)/components/libraries/balloc \
  $(SDK_DIR)/components/libraries/atomic_fifo \
  $(SDK_DIR)/external/micro-ecc \
  $(SDK_DIR)/components/libraries/crypto/backend/nrf_sw \
  $(SDK_DIR)/modules/nrfx/drivers \
  $(SDK_DIR)/modules/nrfx/drivers/include \
  $(SDK_DIR)/modules/nrfx/mdk \
  $(SDK_DIR)/components/libraries/bootloader/ble_dfu \
  $(SDK_DIR)/components/softdevice/common \
  $(SDK_DIR)/external/nano-pb \
  $(SDK_DIR)/external/segger_rtt \
  $(SDK_DIR)/components/libraries/queue \
  $(SDK_DIR)/components/libraries/ringbuf \
  $(SDK_DIR)/components/libraries/mutex \

INCDIRS =  $(CONFIG_DIR) $(FW_SRC)/devices $(FW_SRC) $(SDK_INCS) $(SDK_DIR)/external/nano-pb

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
DEFINES += -DBOARD_CUSTOM -DBLE_STACK_SUPPORT_REQD -DCONFIG_GPIO_AS_PINRESET
DEFINES += -DFLOAT_ABI_HARD -DNRF52 -DNRF52832_XXAA -DNRF52_PAN_74 -DNRF_DFU_SETTINGS_VERSION=1
DEFINES += -DNRF_DFU_SVCI_ENABLED -DNRF_SD_BLE_API_VERSION=6 -DS132 -DSOFTDEVICE_PRESENT
DEFINES += -DSVC_INTERFACE_CALL_AS_NORMAL_FUNCTION -DuECC_ENABLE_VLI_API=0
DEFINES += -DuECC_OPTIMIZATION_LEVEL=3 -DuECC_SQUARE_FUNC=0 -DuECC_SUPPORT_COMPRESSED_POINT=0 -DuECC_VLI_NATIVE_LITTLE_ENDIAN=1

ifeq "$(OPTIMIZATION)" "0"
DEFINES += -DDEBUG
endif

# Compiler Options
GCFLAGS += -O$(OPTIMIZATION) -g3 $(DEVICE_CFLAGS)
GCFLAGS += -ffunction-sections -fdata-sections -fno-strict-aliasing -fno-builtin -fshort-enums -flto -fomit-frame-pointer
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
LDFLAGS += -T$(LSCRIPT) -L$(SDK_DIR)/modules/nrfx/mdk

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
	@echo $(LDFLAGS)
	$(Q) $(CC) $(OBJECTS) $(LDFLAGS) $(LIBS) -o $@
	$(SZ) $@

%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) $< $@

#########################################################################
# default action: build all

all: $(BUILD_DIR)/$(PROJECT).elf $(PROJECT).hex

.PHONY: clean flash reset

clean:
	rm -fR .dep $(BUILD_DIR)

reset:
	$(NRFJPROG) -f nrf52 --reset

flash: $(PROJECT).hex
	$(NRFJPROG) -f nrf52 --program $(PROJECT).hex --sectoranduicrerase
	$(NRFJPROG) -f nrf52 --program $(SETTINGSHEX) --sectorerase

sdflash: $(PROJECT).hex
	$(NRFJPROG) -f nrf52 --eraseall
	$(NRFJPROG) -f nrf52 --program $(SD_HEX)
	$(NRFJPROG) -f nrf52 --program $(PROJECT).hex --sectoranduicrerase
	$(NRFJPROG) -f nrf52 --program $(SETTINGSHEX)
