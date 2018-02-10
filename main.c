/**
 * @defgroup bootloader_secure_ble main.c
 */



#include <stdint.h>
#include "boards.h"
#include "nrf_mbr.h"
#include "nrf_bootloader.h"
#include "nrf_bootloader_app_start.h"
#include "nrf_dfu.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"
#include "app_error.h"
#include "app_error_weak.h"
#include "nrf_bootloader_info.h"


/**@brief Function for application main entry. */
int main(void)
{
    uint32_t ret_val;

    (void) NRF_LOG_INIT(NULL);
    NRF_LOG_DEFAULT_BACKENDS_INIT();

    NRF_LOG_INFO("Inside main");

    ret_val = nrf_bootloader_init();
    APP_ERROR_CHECK(ret_val);

    // Either there was no DFU functionality enabled in this project or the DFU module detected
    // no ongoing DFU operation and found a valid main application.
    // Boot the main application.
    nrf_bootloader_app_start(MAIN_APPLICATION_START_ADDR);

    // Should never be reached.
    NRF_LOG_INFO("After main");
}

/**@brief No button to enter dfu
 */
bool nrf_dfu_button_enter_check(void)
{
    return false;
}

uint32_t nrf_dfu_init_user(void)
{
	// Turn on power pin
	nrf_gpio_cfg_output(PWR_ON);
	nrf_gpio_pin_set(PWR_ON);
}

void app_error_fault_handler(uint32_t id, uint32_t pc, uint32_t info)
{
    NRF_LOG_ERROR("Received a fault! id: 0x%08x, pc: 0x%08x, info: 0x%08x", id, pc, info);
    NVIC_SystemReset();
}


void app_error_handler_bare(uint32_t error_code)
{
    (void)error_code;
    NRF_LOG_ERROR("Received an error: 0x%08x!", error_code);
    NVIC_SystemReset();
}
