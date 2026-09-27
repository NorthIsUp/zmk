/*
 * Copyright (c) 2026 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

// Every key event on the central also fires a lighting burst at the peripheral: more syncs than
// the queues hold, the load of layer-tap effect changes while typing. The host's reports are the
// snapshot, so a dropped, duplicated or reordered key shows there (Review Focus 2, A3).

#include <zephyr/kernel.h>

#include <zmk/event_manager.h>
#include <zmk/events/position_state_changed.h>
#include <zmk/split/central.h>

#if IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)

static uint8_t layer;

// Simulated time only advances when a thread blocks, so elapsed time means a sync call stalled
// key processing. A failure halts the central, which cuts the host's reports short.
static int kinesis_sync_typing_listener(const zmk_event_t *eh) {
    int64_t start = k_uptime_get();

    for (int i = 0; i < 8; i++) {
        if (zmk_split_central_update_kinesis_led(layer++ % 32, 1, true) != 0) {
            k_panic();
        }
    }
    if (zmk_split_central_update_kinesis_backlight(layer % 100, true) != 0 ||
        k_uptime_get() != start) {
        k_panic();
    }
    return ZMK_EV_EVENT_BUBBLE;
}

ZMK_LISTENER(kinesis_sync_typing, kinesis_sync_typing_listener);
ZMK_SUBSCRIPTION(kinesis_sync_typing, zmk_position_state_changed);

#endif // IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
