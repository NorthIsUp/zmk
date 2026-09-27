/*
 * Copyright (c) 2026 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#include <zephyr/init.h>

#include <zmk/backlight.h>

// Calls the K2 peripheral API the way the split peripheral handler does, after backlight init.
static int backlight_update_vals_test(void) {
    zmk_backlight_update_vals((struct backlight_state){.brightness = 60, .on = true});
    // Out-of-range brightness from the wire is clamped to 100.
    zmk_backlight_update_vals((struct backlight_state){.brightness = 250, .on = true});
    zmk_backlight_update_vals((struct backlight_state){.brightness = 80, .on = false});
    return 0;
}

SYS_INIT(backlight_update_vals_test, APPLICATION, 99);
