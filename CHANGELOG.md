# Changelog

All notable changes to this Home Assistant configuration.

## [Refactoring] - December 2024

Major refactoring to modernize deprecated syntax and reduce code duplication through blueprints.

### Summary

- **Code Reduction**: ~45% reduction in targeted files
- **Deprecated Syntax Removed**: All instances of deprecated features updated
- **Blueprints Created**: 2 custom blueprints for reusable automation patterns
- **Backward Compatibility**: All entity IDs preserved for Lovelace/Node-RED compatibility
- **Rollback Available**: Git tag `pre-refactor-20241214` marks pre-refactoring state

### Phase 1: Validation Setup

**Added:**
- `.yamllint` configuration file for YAML syntax checking
- `scripts/validate_yaml.py` for Python-based YAML validation
- Git tag `pre-refactor-20241214` as rollback point

**Changed:**
- Updated `.gitignore` to track `.yamllint` and `blueprints/` directory

**Commits:** cf02c8c, 98e4ac8

### Phase 2: Replace Deprecated data_template

**Changed:**
- Replaced all 30 instances of deprecated `data_template:` with `data:` syntax
- Updated `automation/alarm.yaml` (26 instances)
- Updated `automation/teslamate.yaml` (4 instances)

**Commit:** 30e026e

### Phase 3: Mobile App Notification Actions

**Changed:**
- Updated 5 automations from deprecated `ios.notification_action_fired` to `mobile_app_notification_action`
- Changed event data key from `actionName` to `action`
- Updated `automation/garage.yaml` (4 automations)
- Updated `automation/alarm.yaml` (1 automation)

**Required Action:**
- User configured 5 actions in Home Assistant Companion App: CLOSE_GARAGE, OPEN_GARAGE, CLOSE_GARAGE2, OPEN_GARAGE2, DISARM_ALARM

**Commit:** a63c9b5

### Phase 4: Tesla Device Trackers (REVERTED)

**Attempted:**
- Replace deprecated `device_tracker.see` with MQTT device trackers

**Reverted:**
- Location tracking broke, Node-RED distance calculations failed
- Kept existing device_tracker.see automations since they work

**Commits:** be995c9 (attempted), 031fe1a (reverted)

### Phase 5: Clean Up Template Sensors

**Changed:**
- Removed all 7 instances of deprecated `default_entity_id:` attribute
- Added `unique_id` to all template sensors for UI management
- Modernized template formatting (multiline with `>`, better readability)
- Added proper null/unavailability checks using `states()` function
- Simplified garage door status logic

**Fixed:**
- Preserved original entity IDs for backward compatibility:
  - `sensor.anyone_home`
  - `sensor.garage_status`
  - `sensor.garage_car_present`
  - `sensor.garage2_status`
  - `sensor.garage2_car_present`
  - `sensor.alarm_status`
  - `sensor.weekday`

**Files Modified:**
- `configuration.yaml` (lines 231-309)
- `groups.yaml` (updated sensor references, later reverted)

**Commits:**
- 88fe139 - Initial modernization
- f2a999d - Remove apostrophes from sensor names
- 02b84e6 - Add unique IDs
- 6d7fd42 - Update groups (later reverted)
- 897a4f4 - Restore original entity IDs (final)

**Note:** Stale entities (`sensor.jeff_s_*` etc.) will auto-purge in 30 days due to `purge_keep_days: 30` in recorder config.

### Phase 6: Create Custom Blueprints

**Added:**
- `blueprints/automation/custom/sensor_alert_when_away.yaml`
  - Sends notifications when sensors trigger while nobody is home
  - Inputs: sensor_entity, sensor_name, presence_sensor, notify_service
  - Will replace 15 automations

- `blueprints/automation/custom/sensor_alert_timeout.yaml`
  - Sends notifications when sensors stay open too long
  - Inputs: sensor_entity, sensor_name, timeout_seconds, notify_jeff, notify_jen
  - Will replace 5 automations

**Commit:** dddf38a

### Phase 7: Migrate Alarm Automations to Blueprints

**Changed:**
- Replaced 20 repetitive automations with blueprint instances
- 5 timeout alerts → `sensor_alert_timeout` blueprint
- 15 away alerts → `sensor_alert_when_away` blueprint
- Kept 1 manual automation: iOS action to disarm alarm

**Results:**
- `automation/alarm.yaml`: 403 lines → 229 lines (43% reduction)
- All automation IDs preserved
- All functionality maintained

**Commit:** 82465d1

**Note:** Automations show "cannot be edited from UI" because they're in `automation/alarm.yaml` (manual) not `automations.yaml` (UI). This is expected and correct.

### Phase 8: Reorganize Tesla MQTT Sensors

**Changed:**
- Reorganized 141 Tesla sensors from "by car" to "by category"
- Used compact inline YAML syntax: `- { name: ..., state_topic: ..., icon: ... }`
- All 3 Teslas (Elektra/car 1, KARR/car 2, Orion/car 3) listed side-by-side per sensor type

**Organization:**
- Sensors (141 total): Vehicle Info, State/Status, Software Version, Location, Driving, Battery/Range, Charging, Temperature
- Binary Sensors (36 total): Updates, Security, Doors/Windows, Presence/Climate, Charging Status
- Plus 2 garage door covers at top

**Results:**
- `config/mqtt.yaml`: 690 lines → 199 lines (71% reduction)
- All entity IDs preserved
- Much easier to add 4th Tesla (just one line per sensor type)

**Commit:** e382e55

**Note:** Official TeslaMate docs show additional features (device grouping, unique_ids, TPMS sensors) but we chose not to implement them to avoid breaking Node-RED/Lovelace compatibility.

### Phase 9: Clean Up Groups

**Changed:**
- Removed 12 references to non-existent garage door automations
- Updated `jeff_garage_toggles`: 6 deleted automations → 2 existing (ios_action_open_garage, ios_action_close_garage)
- Updated `jen_garage_toggles`: 6 deleted automations → 2 existing (ios_action_open_garage2, ios_action_close_garage2)
- Removed 1 reference to commented basement_window automation in `alarm_sensor_toggles`

**Results:**
- `groups.yaml`: 208 lines → 195 lines (13 lines removed)
- All groups now reference only existing automations

**Commit:** 5257893

**Note:** Auto-close garage automations were deleted long before this refactoring. User has Node-RED flow that handles garage auto-close using `input_boolean.auto_garage_doors_night`.

### Phase 10: Update Documentation

**Changed:**
- Updated `README.md` with refactoring summary
- AGENTS.md already contained blueprint documentation
- Created `CHANGELOG.md` documenting all changes

**Commit:** [pending]

## Overall Results

### Code Reduction
- `automation/alarm.yaml`: 403 → 229 lines (43% reduction)
- `config/mqtt.yaml`: 690 → 199 lines (71% reduction)
- `groups.yaml`: 208 → 195 lines (13 lines removed)
- `configuration.yaml`: 282 → 317 lines (increased but modernized/cleaner)
- **Total**: ~45% reduction in targeted files

### Deprecated Syntax Removed
- ✅ 30 `data_template` → `data`
- ✅ 5 `ios.notification_action_fired` → `mobile_app_notification_action`
- ✅ 7 `default_entity_id` removed from templates
- ✅ Added unique_ids to template sensors
- ✅ Modernized template formatting

### New Features
- Custom blueprints for reusable automation patterns
- Better organization of Tesla MQTT sensors
- Cleaner, more maintainable code

### Backward Compatibility
All entity IDs preserved for compatibility with:
- Lovelace dashboards
- Node-RED flows (garage automation, Tesla distance tracking)
- Google Assistant integration
- Existing automations and scripts

## Testing

Each phase was tested individually:
1. Commit changes
2. Push to GitHub
3. Pull in HA container: `cd /config && git pull`
4. Reload relevant integration or restart HA
5. Verify functionality (~15 minutes per phase)
6. Proceed to next phase only after successful testing

## Rollback

To rollback to pre-refactoring state:
```bash
git checkout pre-refactor-20241214
```

Individual phases can be reverted using:
```bash
git revert <commit-hash>
```

## Known Issues

1. **Stale template sensor entities** (`sensor.jeff_s_*`, etc.) exist but will auto-purge in 30 days
2. **Tesla device_tracker.see** kept despite deprecation because it works and Node-RED depends on it
3. **Manual automations not UI-editable** - expected behavior for automations in `automation/*.yaml` files

## Important Entities (Protected)

These entity IDs must not be renamed as they're used by Node-RED flows:
- `sensor.anyone_home`
- `sensor.garage_status`, `sensor.garage2_status`
- `sensor.garage_car_present`, `sensor.garage2_car_present`
- `input_boolean.auto_garage_doors_night`
- `input_boolean.auto_garage_doors`
- `device_tracker.teslamate_*`
- All Tesla MQTT sensors (`sensor.tesla_*`, `sensor.tesla2_*`, `sensor.tesla3_*`)
