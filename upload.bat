#@echo off
setlocal

set BOOT_HEX=Release/nrf52boot.hex
set SD_HEX=../SDK/components/softdevice/s132/hex/s132_nrf52_5.0.0_softdevice.hex
set ADV_NAME=../Config/settings.hex

nrfjprog -f nrf52 --eraseall
nrfjprog -f nrf52 --program %SD_HEX%
nrfjprog -f nrf52 --program %BOOT_HEX%
nrfjprog -f nrf52 --program %ADV_NAME%

exit /b 0
