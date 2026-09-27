/*
 * Copyright (c) 2026 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

// Drives the Kinesis sync API on the central; the peripheral's log is the snapshot.

#include <zephyr/init.h>
#include <zephyr/kernel.h>

#include <zmk/split/central.h>

#if IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)

// 15 LED updates against a 5-slot queue, back to back on the system work queue: only
// layers 20-24 may reach the peripheral. Simulated time only advances when a thread
// blocks, so any elapsed time means an enqueue blocked. A failure halts the central,
// which drops the burst lines from the peripheral snapshot.
static void kinesis_sync_burst(struct k_work *work) {
    int64_t start = k_uptime_get();

    for (uint8_t layer = 10; layer < 25; layer++) {
        if (zmk_split_central_update_kinesis_led(layer, 1, true) != 0) {
            k_panic();
        }
    }
    if (zmk_split_central_update_kinesis_backlight(40, false) != 0 || k_uptime_get() != start) {
        k_panic();
    }
}

static K_WORK_DELAYABLE_DEFINE(kinesis_sync_burst_work, kinesis_sync_burst);

// Set before the peripheral connects, so only the ready-time replay can deliver it.
static int kinesis_sync_test_init(void) {
    zmk_split_central_update_kinesis_led(3, 2, true);
    zmk_split_central_update_kinesis_backlight(60, true);
    k_work_schedule(&kinesis_sync_burst_work, K_SECONDS(3));
    return 0;
}

SYS_INIT(kinesis_sync_test_init, APPLICATION, 99);

#endif // IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
