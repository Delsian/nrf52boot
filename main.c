/**
 * @defgroup bootloader_secure_ble main.c
 */



#include <stdint.h>
#include "boards.h"
#include "nrf_mbr.h"
#include "nrf_bootloader.h"
#include "nrf_bootloader_app_start.h"
#include "nrf_dfu.h"
#include "nrf_delay.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"
#include "app_error.h"
#include "app_timer.h"
#include "app_error_weak.h"
#include "nrf_bootloader_info.h"
#include "rdev_led.h" // Colors

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

/**@brief Long button press to enter dfu
 */
#define BUTTON_DELAY_SEC 5
#define BLINK_TICK_TIMEOUT 200
#define BUTTON_DELAY_DFU (BUTTON_DELAY_SEC*1000)/BLINK_TICK_TIMEOUT

//APP_TIMER_DEF(tLedTimer);
void PcaInit(void);
void PcaLedColor(LedColor color);
static LedColor tColors[2];

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
		if (nrf_gpio_pin_read(BUTTON1) == 1)
			return false;
		nrf_delay_ms(BLINK_TICK_TIMEOUT);
		LedTickHandler();
	}
    return true;
}

uint32_t nrf_dfu_init_user(void)
{
	// Turn on power pin
	nrf_gpio_cfg_output(PWR_ON);
	nrf_gpio_pin_set(PWR_ON);

	// Init PCA chip
	PcaInit();

	// Init timer
	//app_timer_create(&tLedTimer, APP_TIMER_MODE_REPEATED, LedTickHandler);
	//app_timer_start(tLedTimer, BLINK_TICK_TIMEOUT, NULL);

}

void nrf_dfu_advertising_led(uint8_t state)
{
	if (state)
		PcaLedColor(COLOR_OLIVE);
}
void nrf_dfu_connected_led(uint8_t state)
{
	if (state)
		PcaLedColor(COLOR_NAVY);
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
