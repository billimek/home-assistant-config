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
- Automation files in `automation/` are merged via `!include_dir_merge_list` in configuration.yaml:82
- UI-created automations automatically go to `automations.yaml`
- Always quote state values like 'on'/'off' and strings with special characters
- Entity naming pattern: `{domain}.{location}_{device}_{attribute}`

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
These entity IDs are referenced by Node-RED flows, Lovelace dashboards, and multiple automations. Renaming them will break integrations:
- `sensor.anyone_home` - Home/away status (used by 15+ automations)
- `sensor.garage_status`, `sensor.garage2_status` - Garage door status sensors
- `sensor.garage_car_present`, `sensor.garage2_car_present` - Car presence sensors
- `input_boolean.auto_garage_doors_night` - Node-RED garage auto-close control
- `input_boolean.auto_garage_doors` - Node-RED garage automation control
- `device_tracker.tesla_location`, `device_tracker.tesla2_location`, `device_tracker.tesla3_location` - template trackers (configuration.yaml) fed by TeslaMate's discovered `device_tracker.elektra/karr/orion`. The Proximity integration ("Home" entry) tracks them to produce the distance sensors below. **Keep these ids.**
- `sensor.home_tesla2_location_distance`, `sensor.home_tesla3_location_distance` - Proximity distance (ft) for KARR and Orion; Node-RED's garage auto close/open triggers on these crossing 200 ft. Keep ids, numeric state and ft units. (`sensor.home_tesla_location_distance` for Elektra is only shown on the dashboard.)

## Tesla / TeslaMate
- Tesla telemetry comes from TeslaMate's MQTT discovery (`MQTT_DISCOVERY=true` in the k8s config): devices Elektra (car 1), KARR (car 2), Orion (car 3), entity ids like `sensor.elektra_battery`. There are no hand-written Tesla MQTT sensors any more.
- `tesla_custom` provides the car controls (buttons, locks, charge limit, seat heaters, climate). Its 11 telemetry entities per car that collide with TeslaMate names were renamed `*_tc_*` and disabled so the discovered entities own the clean ids.
- Node-RED only consumes the three tracker ids and two distance sensors above (verified against flows.json); it reads no `sensor.tesla*` entities and no `teslamate/` MQTT topics.
- `config/mqtt.yaml` still has raw `sensor.tesla*_latitude/longitude` as a temporary fallback for the location trackers; remove after a real drive confirms the discovered trackers update correctly.
