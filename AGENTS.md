# Agent Guidelines for Home Assistant Config

## Repository Overview
Home Assistant YAML configuration for a smart home running on Kubernetes. No build/test system - validation happens on HA restart.

## Validation & Linting
- **Recommended**: Install and run `yamllint .` for YAML syntax checking
- **Home Assistant CLI**: `ha core check` (if HA CLI installed locally)
- **Docker validation**: `docker run --rm -v $(pwd):/config homeassistant/home-assistant:latest python -m homeassistant --script check_config --config /config`
- Production validation occurs on Home Assistant restart in Kubernetes cluster

## Code Style
- **Format**: YAML with 2-space indentation
- **Entity IDs**: snake_case (e.g., `sensor.garage_status`, `cover.jeff_garage_door`)
- **Automation Structure**: Must include `id`, `alias`, `trigger`, `action`; optional `initial_state`, `condition`
- **Comments**: Use `##` for section headers, `#` for inline comments
- **Templates**: Jinja2 syntax in `{% %}` blocks for state/template sensors
- **Secrets**: Use `!env_var VARIABLE_NAME` for sensitive data (never commit actual secrets to `secrets.yaml`)
- **File Organization**: Split by domain - automations in `automation/`, sensors in `config/`, scripts in `scripts/`
- **configuration.yaml layout**: it only holds core settings and `!include`s. Helpers and templates live in `config/input_boolean.yaml`, `config/input_datetime.yaml`, `config/timer.yaml`, `config/template.yaml`; groups in `config/groups.yaml`; zones in `config/zones.yaml`. `tools/` holds helper scripts (not HA scripts)

## Key Conventions
- Automation files in `automation/` are merged via `!include_dir_merge_list` in configuration.yaml
- Scripts in `scripts/` are merged via `!include_dir_merge_named` (one file may define several named scripts)
- UI-created automations automatically go to `automations.yaml`
- Always quote state values like 'on'/'off' and strings with special characters
- Entity naming pattern: `{domain}.{location}_{device}_{attribute}`
- Alarm code: `code: !env_var ALARMCD` (the HA automation trace stores the resolved code in plain text)
- Reload after editing: `automation.reload` for automations, `script.reload` for scripts, `input_datetime.reload` etc. for helpers. A new helper *domain* key in configuration.yaml needs a restart (`default_config` already loads the common ones).

## Automations (formerly Node-RED)
All automation logic is native Home Assistant YAML. It used to run in Node-RED (configuration kept in https://github.com/billimek/node-red-config); the Node-RED flows were migrated and disabled in October 2026, so Node-RED consumes nothing from this repo any more. Where things live:

| File | What it does |
|---|---|
| `automation/alarm_logic.yaml` | midnight lights-off + arm, 05:00 disarm, disarm on arrival, arm when everyone leaves (gated by `input_boolean.auto_arm_disarm_alarm_night` for midnight/05:00 and `input_boolean.auto_alarm_presence` for arrive/leave; guest mode skips the leave arm and sends a passive push) |
| `automation/alarm_notifications.yaml` | armed / disarmed / triggered / suspicious-disarm pushes + Discord for a triggered alarm (gated by `input_boolean.notify_alarm_*`) |
| `automation/alarm.yaml` | sensor alerts (blueprints), iOS DISARM_ALARM action, AlarmDecoder watchdog |
| `automation/guest_mode.yaml` | `input_boolean.guest_mode` auto-off (72 h `timer.guest_mode`). While on: no automatic alarm arming (`alarm_logic.yaml`), `sensor.anyone_home` reads `home` (silences the away sensor alerts), porch and pool camera pushes muted (`custom_filter` in `automations.yaml`) |
| `automation/doorbell.yaml` | doorbell ring push (Dahua AD410) + watchdog that alerts if the Dahua listener goes quiet for 6 h (`input_datetime.dahua_last_event`) |
| `automation/garage.yaml` | iOS open/close garage actions |
| `automation/garage_notifications.yaml` | door-opened push, still-open-when-leaving, 2 h weekday nag (+ optional auto-close), 10 pm close (`input_boolean.auto_garage_doors_night`) |
| `automation/garage_tesla.yaml` | KARR/Orion geofence: close on leaving, open on arriving (gated by `input_boolean.auto_garage_doors`) |
| `automation/garage_led.yaml` | garage-door state on Inovelli LED bars via `zwave_js` config parameters (porch/garage switch param 8 as partial values, stairs dimmers params 13/14). |
| `automation/lights.yaml`, `automation/lights_motion.yaml` | dusk/schedule lights (porch, sunroom/foyer/trees, cabinet, plant lights) and motion/event lights (garage, deck, desk via Wyze MQTT, stairs) |
| `automation/presence.yaml` | arrival push, Jen came home, Ecobee away/resume and Nest eco (skipped in guest mode) |
| `automation/water.yaml` | basement and sump pump leak alerts |
| `automation/home_health.yaml` | leak sensor battery, printer toner, fridge door, freeze warning (`sensor.forecast_low_2_nights`, a trigger-based template sensor in `config/template.yaml` built from the Ecobee daily forecast; the same block also feeds `sensor.next_rain`) |
| `automation/car_alerts.yaml` | 21:00 plug-in reminder (any car home, unplugged, under 50 %), tire pressure push |
| `automation/network.yaml` | new WiFi device alert |
| `scripts/lights_off.yaml` | `script.lights_off`, used at midnight (leaves the basement lights on while guest mode is on) |
| `scripts/notify.yaml` | `script.notify_phones` (central iOS push: audience, level, tag, group, url, action buttons) and `script.notify_clear`. New pushes should use it, not `notify.mobile_app_*` directly. While `input_boolean.notify_test_mode` is on, everything goes to Jeff's phone only |
| `docs/notifications.md` | catalog of every push (trigger, who, level, buttons), the avatar table, the action-id convention, and how to add or test a notification |
| `scripts/alarm.yaml` | `script.alarm_arm_home`, `_arm_away`, `_arm_night`, `_disarm`: dashboard buttons that send `!env_var ALARMCD` so the tile's keypad popup is not needed |
| `scripts/camera_notifications.yaml` | `script.mute_camera_notifications` (dashboard "Mute 1 hour"): turns off each camera toggle that is on and starts its `timer.camera_<name>_mute` |
| `automation/notification_actions.yaml` | single handler for iOS action buttons; action ids are `KIND\|arg\|arg` (disarm, garage open/close/snooze, sensor snooze, camera mute, water silence). Snoozes and mutes use the restoring `timer.*` helpers |
| `automations.yaml` | the 5 Frigate camera pushes (SgtBatten blueprint, Clip button uses the HLS `master.m3u8` URL because iOS cannot play the proxy's range-less `clip.mp4`; one per camera: person/dog/cat only, `custom_filter` carries the weekday/overnight/nobody-home rules, "Mute 1 h" button). They bypass `notify_phones` (so `notify_test_mode` does not apply); `notify_group` is `ALL_DEVICES`, set it to `mobile_app_jeffsphone` to test |

Notes: Jen's phone (`notify.mobile_app_jensphone`) is included in the shared household pushes; the siren, Slack and the cleaning-calendar disarm were dropped on purpose. Automation timers (garage lights, deck lights, etc.) live in memory like Node-RED's did, so an HA restart while one is running leaves that light on.

## Automation map
`perl tools/automation_map.pl` regenerates `docs/automation_map.html`, a clickable flow map (triggers, automations, scripts, destinations such as Jen's phone) built by reading `automation/`, `scripts/` and the custom blueprints. There is no YAML parser on the box, so it reads by indentation and expects literal service names (`script.notify_phones` with `audience:`, `notify.*`). Re-run it after changing automations.

## Custom Blueprints
This repository includes custom blueprints for common automation patterns. Blueprints are located in `blueprints/automation/custom/`:

### sensor_alert_when_away.yaml
Sends notification when a sensor (door/window/motion) triggers while nobody is home.
- **Inputs**: sensor_entity, sensor_name, presence_sensor (default: sensor.anyone_home), audience (default: jeff). Pushes via `script.notify_phones`; the "Snooze 1 h" button starts `timer.snooze_<sensor key>` (key = sensor id after `ser2sock_10000_`); the push clears when the sensor closes
- **Usage**: Used by 15 alarm automations in `automation/alarm.yaml`
- **Example**:
  ```yaml
  - id: away_front_door
    alias: 'Alert when front door is open and nobody home'
    use_blueprint:
      path: custom/sensor_alert_when_away.yaml
      input:
        sensor_entity: binary_sensor.ser2sock_10000_front_door
        sensor_name: "Front door"
        presence_sensor: sensor.anyone_home
  ```

### sensor_alert_timeout.yaml
Sends notification when a sensor (door/window) stays open for too long.
- **Inputs**: sensor_entity, sensor_name, timeout_seconds (default: 300), notify_jeff (bool), notify_jen (bool)
- **Usage**: Used by 5 timeout automations in `automation/alarm.yaml`
- **Example**:
  ```yaml
  - id: timeout_front_door
    alias: 'Alert when front door is opened for too long'
    use_blueprint:
      path: custom/sensor_alert_timeout.yaml
      input:
        sensor_entity: binary_sensor.ser2sock_10000_front_door
        sensor_name: "Front door"
        timeout_seconds: 300
        notify_jeff: true
        notify_jen: true
  ```

## Important Entity IDs (Do Not Rename)
These entity IDs are referenced by Lovelace dashboards and automations. Renaming them will break integrations:
- `sensor.anyone_home` - Home/away status (used by 15+ automations)
- `zone.home` - its state is the number of people home; the presence, alarm and light automations trigger on it
- `sensor.garage_status`, `sensor.garage2_status` - Garage door status sensors
- `sensor.garage_car_present`, `sensor.garage2_car_present` - Car presence sensors
- `cover.jeff_garage_door`, `cover.jen_garage_door` and `binary_sensor.og_jeff_vehicle`, `binary_sensor.og_jen_vehicle` - used by the garage automations (the vehicle sensors are "car in the garage" for the arrival auto-open)
- `input_boolean.auto_garage_doors_night` - 10 pm garage auto-close toggle (`automation/garage_notifications.yaml`)
- `input_boolean.auto_garage_doors` - Tesla geofence garage automation kill switch (`automation/garage_tesla.yaml`)
- `device_tracker.elektra`, `device_tracker.karr`, `device_tracker.orion` - TeslaMate-discovered trackers (car 1, 2, 3). The Proximity integration ("Home" entry) tracks them directly to produce the distance sensors below.
- `sensor.home_karr_distance`, `sensor.home_orion_distance` - Proximity distance (ft) for KARR and Orion; `automation/garage_tesla.yaml` triggers on these crossing 200 ft (KARR = Jeff's door, Orion = Jen's door). Keep numeric state and ft units. (`sensor.home_elektra_distance` for Elektra is only shown on the dashboard.)

## Tesla / TeslaMate
- EV charging cost: monthly `utility_meter` UI helpers (`sensor.<car>_charging_energy_month`) on TeslaMate's `sensor.<car>_energy_added`, priced in `config/template.yaml` (`sensor.<car>_charging_cost_month`, `sensor.ev_charging_cost_month`) from `input_number.ev_electricity_rate` and `input_number.ev_charging_loss` (`config/input_number.yaml`). Shown on the Cars tab.
- Tesla telemetry comes from TeslaMate's MQTT discovery (`MQTT_DISCOVERY=true` in the k8s config): devices Elektra (car 1), KARR (car 2), Orion (car 3), entity ids like `sensor.elektra_battery`. There are no hand-written Tesla MQTT sensors any more.
- `tesla_custom` provides the car controls (buttons, locks, charge limit, seat heaters, climate). Its 11 telemetry entities per car that collide with TeslaMate names were renamed `*_tc_*` and disabled so the discovered entities own the clean ids.
- The only automations that consume Tesla data are the two geofence automations in `automation/garage_tesla.yaml`, via the two distance sensors above (Elektra is not used). Node-RED no longer reads anything.
- The old raw `sensor.tesla*_latitude/longitude` MQTT sensors (a temporary fallback for the location trackers) were removed (`config/mqtt.yaml` has since been deleted entirely, along with the unused legacy MQTT garage covers) after a real drive on 2026-10-05 showed the discovered trackers update about once a second and drive the Orion geofence correctly.
