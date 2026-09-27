/*
 * Copyright (c) 2026 The ZMK Contributors
 *
 * SPDX-License-Identifier: MIT
 */

#define DT_DRV_COMPAT zmk_behavior_dump_metadata

#include <zephyr/device.h>
#include <drivers/behavior.h>
#include <zephyr/logging/log.h>

#include <zmk/keymap.h>
#include <zmk/behavior.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#if IS_ENABLED(CONFIG_ZMK_BEHAVIOR_METADATA) && DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

// Logs what ZMK Studio (Clique) reads over RPC: each behavior's display name and
// param1 values, then every layer name.
static int on_dump_metadata_binding_pressed(struct zmk_behavior_binding *binding,
                                            struct zmk_behavior_binding_event event) {
    STRUCT_SECTION_FOREACH(zmk_behavior_ref, item) {
        LOG_DBG("behavior %s display \"%s\"", item->device->name, item->metadata.display_name);

        struct behavior_parameter_metadata md = {0};
        if (behavior_get_parameter_metadata(item->device, &md) < 0) {
            continue;
        }
        for (size_t s = 0; s < md.sets_len; s++) {
            for (size_t v = 0; v < md.sets[s].param1_values_len; v++) {
                const struct behavior_parameter_value_metadata *pv = &md.sets[s].param1_values[v];
                LOG_DBG("param %s %d 0x%x \"%s\"", item->device->name, pv->type, pv->value,
                        pv->display_name);
            }
        }
    }

    for (zmk_keymap_layer_id_t id = 0; id < ZMK_KEYMAP_LAYERS_LEN; id++) {
        LOG_DBG("layer %d name \"%s\"", id, zmk_keymap_layer_name(id));
    }

    return ZMK_BEHAVIOR_OPAQUE;
}

static int on_dump_metadata_binding_released(struct zmk_behavior_binding *binding,
                                             struct zmk_behavior_binding_event event) {
    return ZMK_BEHAVIOR_OPAQUE;
}

static const struct behavior_driver_api behavior_dump_metadata_driver_api = {
    .binding_pressed = on_dump_metadata_binding_pressed,
    .binding_released = on_dump_metadata_binding_released,
};

BEHAVIOR_DT_INST_DEFINE(0, NULL, NULL, NULL, NULL, POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,
                        &behavior_dump_metadata_driver_api);

#endif // IS_ENABLED(CONFIG_ZMK_BEHAVIOR_METADATA) && DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)
