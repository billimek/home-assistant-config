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
