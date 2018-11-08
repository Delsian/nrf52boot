/** @file
 *
 * @defgroup bootloader_secure_ble main.c
 * @{
 * @ingroup dfu_bootloader_api
 * @brief Bootloader project main file for secure DFU.
 *
 */


#include <stdint.h>
#include "boards.h"
#include "nrf_mbr.h"
#include "nrf_bootloader.h"
#include "nrf_bootloader_app_start.h"
#include "nrf_bootloader_dfu_timers.h"
#include "nrf_dfu.h"
#include "nrf_bootloader_wdt.h"
#include "nrf_delay.h"
#include "nrf_clock.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"
#include "app_error.h"
#include "app_error_weak.h"
#include "app_timer.h"
#include "nrf_bootloader_info.h"
#include "../controller/src/pca9685.h"
#include "rdev_led.h" // Colors


/**@brief Long button press to enter dfu
 */
#define BUTTON_DELAY_SEC 5
#define BLINK_TICK_TIMEOUT 6000
#define BUTTON_DELAY_DFU (BUTTON_DELAY_SEC*1000)/BLINK_TICK_TIMEOUT

void PcaInit(void);
void PcaLedColor(LedColor color);
static LedColor tColors[2] = {
		COLOR_BLACK,
		COLOR_GREEN
};
APP_TIMER_DEF(tLedTimer);

static void LedTickHandler()
{
    static LedColor c;

    if (c == tColors[0])
        c = tColors[1];
    else
        c = tColors[0];
    PcaLedColor(c);
}

bool nrf_dfu_button_enter_check(void)
{
    nrf_gpio_cfg_input(BUTTON1, NRF_GPIO_PIN_PULLUP);
    uint16_t usDfuDelay = BUTTON_DELAY_DFU;
    tColors[0] = COLOR_ORANGE;
    tColors[1] = COLOR_TURQUOISE;
    while (usDfuDelay--) {
        if (nrf_gpio_pin_read(BUTTON1) == 1) {
/* Enable this in release
            if (usDfuDelay > BUTTON_DELAY_DFU-4) {
                // Ignore too short button press for power on
                nrf_gpio_pin_clear(PWR_ON); // switch off
                while(1);
            }
*/
            return false;
        }
        nrf_delay_ms(BLINK_TICK_TIMEOUT);
        LedTickHandler();
    }
    return true;
}

static void on_error(void)
{
    NRF_LOG_FINAL_FLUSH();

#if NRF_MODULE_ENABLED(NRF_LOG_BACKEND_RTT)
    // To allow the buffer to be flushed by the host.
    nrf_delay_ms(100);
#endif
#ifdef NRF_DFU_DEBUG_VERSION
    NRF_BREAKPOINT_COND;
#endif
    NVIC_SystemReset();
}

void app_error_fault_handler(uint32_t id, uint32_t pc, uint32_t info)
{
    NRF_LOG_ERROR("Received a fault! id: 0x%08x, pc: 0x%08x, info: 0x%08x", id, pc, info);
    on_error();
}

uint32_t nrf_dfu_init_user(void)
{

	// Init PCA chip
	PcaInit();
	PcaLedColor(COLOR_BLUE);

	// Init timer
	if (!nrf_clock_lf_is_running())
    {
        nrf_clock_task_trigger(NRF_CLOCK_TASK_LFCLKSTART);
    }
	app_timer_init();
	app_timer_create(&tLedTimer, APP_TIMER_MODE_REPEATED, LedTickHandler);
	app_timer_start(tLedTimer, BLINK_TICK_TIMEOUT, NULL);
	return 0;
}

/**
 * @brief Function notifies certain events in DFU process.
 */
static void dfu_observer(nrf_dfu_evt_type_t evt_type)
{
    switch (evt_type)
    {
        case NRF_DFU_EVT_DFU_FAILED:
            tColors[0] = COLOR_RED;
            tColors[1] = COLOR_BLACK;
        	NRF_LOG_INFO("EVT_DFU_FAILED");
        	break;
        case NRF_DFU_EVT_DFU_ABORTED:
            tColors[0] = COLOR_RED;
            tColors[1] = COLOR_BLUE;
        	NRF_LOG_INFO("EVT_DFU_ABORTED");
            break;
        case NRF_DFU_EVT_DFU_INITIALIZED:
        	NRF_LOG_INFO("EVT_DFU_INITIALIZED");
            break;
        case NRF_DFU_EVT_TRANSPORT_ACTIVATED:
            tColors[0] = COLOR_BLUE;
            tColors[1] = COLOR_BLUE;
        	NRF_LOG_INFO("EVT_DFU_ACTIVATED");
            break;
        case NRF_DFU_EVT_TRANSPORT_DEACTIVATED:
            tColors[0] = COLOR_GREEN;
            tColors[1] = COLOR_BLACK;
        	NRF_LOG_INFO("EVT_DFU_DEACTIVATED");
            break;
        default:
            break;
    }
}

/**@brief Function for application main entry. */
int main(void)
{
    uint32_t ret_val;

	// Turn on power pin
	nrf_gpio_cfg_output(PWR_ON);
	nrf_gpio_pin_set(PWR_ON);

    // Protect MBR and bootloader code from being overwritten.
    ret_val = nrf_bootloader_flash_protect(0, MBR_SIZE, false);
    APP_ERROR_CHECK(ret_val);
    ret_val = nrf_bootloader_flash_protect(BOOTLOADER_START_ADDR, BOOTLOADER_SIZE, false);
    APP_ERROR_CHECK(ret_val);

    (void) NRF_LOG_INIT(nrf_bootloader_dfu_timer_counter_get);
    NRF_LOG_DEFAULT_BACKENDS_INIT();

    ret_val = nrf_bootloader_init(dfu_observer);
    APP_ERROR_CHECK(ret_val);
}



