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
| `automation/alarm_logic.yaml` | midnight lights-off + arm, 05:00 disarm, disarm on arrival, arm when everyone leaves (gated by `input_boolean.auto_arm_disarm_alarm_night`, `auto_disarm_alarm_when_home`, `auto_arm_alarm_when_gone` and `input_select.alarm_mode`) |
| `automation/alarm_notifications.yaml` | armed / disarmed / triggered / suspicious-disarm pushes + Discord for a triggered alarm (gated by `input_boolean.notify_alarm_*`) |
| `automation/alarm.yaml` | sensor alerts (blueprints), iOS DISARM_ALARM action, AlarmDecoder watchdog |
| `automation/doorbell.yaml` | doorbell ring push (Dahua AD410) + watchdog that alerts if the Dahua listener goes quiet for 6 h (`input_datetime.dahua_last_event`) |
| `automation/garage.yaml` | iOS open/close garage actions |
| `automation/garage_notifications.yaml` | door-opened push, still-open-when-leaving, 2 h weekday nag (+ optional auto-close), 10 pm close (`input_boolean.auto_garage_doors_night`) |
| `automation/garage_tesla.yaml` | KARR/Orion geofence: close on leaving, open on arriving (gated by `input_boolean.auto_garage_doors`) |
| `automation/garage_led.yaml` | garage-door state on Inovelli LED bars via `zwave_js` config parameters (porch/garage switch param 8 as partial values, stairs dimmers params 13/14). The garage switch (node 10) currently rejects param 8 |
| `automation/lights.yaml`, `automation/lights_motion.yaml` | dusk/schedule lights (porch, sunroom/foyer/trees, cabinet, plant lights) and motion/event lights (garage, deck, desk via Wyze MQTT, stairs) |
| `automation/presence.yaml` | arrival push, Jen came home, Ecobee away/resume |
| `automation/water.yaml` | basement and sump pump leak alerts |
| `automation/network.yaml` | new WiFi device alert |
| `scripts/lights_off.yaml` | `script.lights_off`, used at midnight |

Notes: Jen's phone (`notify.mobile_app_jensphone`) is included in the shared household pushes; the siren, Slack and the cleaning-calendar disarm were dropped on purpose. Automation timers (garage lights, deck lights, etc.) live in memory like Node-RED's did, so an HA restart while one is running leaves that light on.

## Custom Blueprints
This repository includes custom blueprints for common automation patterns. Blueprints are located in `blueprints/automation/custom/`:

### sensor_alert_when_away.yaml
Sends notification when a sensor (door/window/motion) triggers while nobody is home.
- **Inputs**: sensor_entity, sensor_name, presence_sensor (default: sensor.anyone_home), notify_service
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
        notify_service: notify.mobile_app_jeffsphone
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
- `device_tracker.tesla_location`, `device_tracker.tesla2_location`, `device_tracker.tesla3_location` - template trackers (configuration.yaml) fed by TeslaMate's discovered `device_tracker.elektra/karr/orion`. The Proximity integration ("Home" entry) tracks them to produce the distance sensors below. **Keep these ids.**
- `sensor.home_tesla2_location_distance`, `sensor.home_tesla3_location_distance` - Proximity distance (ft) for KARR and Orion; `automation/garage_tesla.yaml` triggers on these crossing 200 ft (KARR = Jeff's door, Orion = Jen's door). Keep ids, numeric state and ft units. (`sensor.home_tesla_location_distance` for Elektra is only shown on the dashboard.)

## Tesla / TeslaMate
- Tesla telemetry comes from TeslaMate's MQTT discovery (`MQTT_DISCOVERY=true` in the k8s config): devices Elektra (car 1), KARR (car 2), Orion (car 3), entity ids like `sensor.elektra_battery`. There are no hand-written Tesla MQTT sensors any more.
- `tesla_custom` provides the car controls (buttons, locks, charge limit, seat heaters, climate). Its 11 telemetry entities per car that collide with TeslaMate names were renamed `*_tc_*` and disabled so the discovered entities own the clean ids.
- The only automations that consume Tesla data are the two geofence automations in `automation/garage_tesla.yaml`, via the two distance sensors above (Elektra is not used). Node-RED no longer reads anything.
- `config/mqtt.yaml` still has raw `sensor.tesla*_latitude/longitude` as a temporary fallback for the location trackers; remove after confirming the discovered trackers update correctly (a real arrival on 2026-10-05 triggered the Orion geofence correctly via the distance sensor).
