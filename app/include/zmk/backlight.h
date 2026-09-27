/*
 * Copyright (c) 2021 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

struct backlight_state {
    uint8_t brightness;
    bool on;
};

int zmk_backlight_on(void);
int zmk_backlight_off(void);
int zmk_backlight_toggle(void);
bool zmk_backlight_is_on(void);

// Split peripheral: apply the central's state. brightness is unscaled (0-100, as stored);
// BRT_SCALE is applied locally.
int zmk_backlight_update_vals(struct backlight_state new_state);

int zmk_backlight_set_brt(uint8_t brightness);
uint8_t zmk_backlight_get_brt(void);
uint8_t zmk_backlight_calc_brt(int direction);
uint8_t zmk_backlight_calc_brt_cycle(void);
