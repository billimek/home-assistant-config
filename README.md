# Home Assistant Configuration

[Home Assistant Core](https://home-assistant.io/) running on [my Kubernetes cluster](https://github.com/billimek/k8s-gitops).  This configuration is read and persisted within Home Assistant.

## Screenshots

Default View
![default view](https://i.imgur.com/bn19oeC.png "Default View")

Camera View
![camera view](https://i.imgur.com/1wTt9ja.png "Camera View")

Z-Wave View
![z-wave view](https://i.imgur.com/ZUTuq4S.png "Z-Wave View")

Climate View
![climate view](https://i.imgur.com/ccK8AcO.png "Climate View")

Security View
![security view](https://i.imgur.com/p0OpPCs.png "Security View")

## Points of interest

* Home-Assistant is running within a kubernetes cluster running the the [home-assistant helm chart](https://github.com/k8s-at-home/charts/tree/master/charts/stable/home-assistant)
* Automations are mostly performed via [node-red](https://nodered.org/) with the node-red configuration hosted in [this repo](https://github.com/billimek/node-red-config)
* In addition to use git to control the configuration, an [embeded](https://github.com/billimek/k8s-gitops/blob/master/default/home-assistant/home-assistant.yaml#L67-L82) instance of the [VSCode server](https://github.com/cdr/code-server) using the [home-assistant config helper extension](https://marketplace.visualstudio.com/items?itemName=keesschollaart.vscode-home-assistant) is leveraged to make live changes to the configuration files

## Recent Refactoring (December 2024)

This configuration underwent a major refactoring to modernize deprecated syntax and reduce code duplication through blueprints.

### Key Improvements

**Code Reduction:**
- `automation/alarm.yaml`: 403 → 229 lines (43% reduction)
- `config/mqtt.yaml`: 690 → 199 lines (71% reduction)
- Overall ~45% reduction in targeted files

**Modernizations:**
- Removed all deprecated `data_template` syntax (30 instances)
- Migrated from deprecated iOS notification actions to `mobile_app` events
- Modernized template sensors with unique IDs and null-safe checks
- Created custom blueprints for reusable automation patterns

**New Features:**
- Custom blueprints in `blueprints/automation/custom/`:
  - `sensor_alert_when_away.yaml` - Alerts when sensors trigger while nobody home
  - `sensor_alert_timeout.yaml` - Alerts when sensors stay open too long
- Better organization of Tesla MQTT sensors (grouped by category vs by car)

**Rollback:** Git tag `pre-refactor-20241214` marks the pre-refactoring state for easy rollback if needed.

See [CHANGELOG.md](CHANGELOG.md) for detailed changes by phase.
