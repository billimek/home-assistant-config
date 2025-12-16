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
- `device_tracker.teslamate_*` - Tesla location tracking (used by Node-RED distance calculations)
- All Tesla MQTT sensors (`sensor.tesla_*`, `sensor.tesla2_*`, `sensor.tesla3_*`) - used by Node-RED flows
