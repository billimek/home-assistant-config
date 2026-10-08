# iOS notifications

Every push goes through `script.notify_phones` ([scripts/notify.yaml](../scripts/notify.yaml)) except the Frigate camera pushes (SgtBatten blueprint, [automations.yaml](../automations.yaml)) and the two Discord messages. Action buttons are handled by one automation, [automation/notification_actions.yaml](../automation/notification_actions.yaml).

## Catalog

"Both" means Jeff's and Jen's phones. Levels: **passive** (quiet, Notification Summary), **active**, **time-sensitive** (breaks through Focus), **critical** (bypasses mute and Do Not Disturb).

| Notification | Fires when | Who | Level | Buttons | Cleared |
|---|---|---|---|---|---|
| 🚨 Alarm triggered | panel goes `triggered` (toggle `notify_alarm_triggered`) | both + Discord | critical | **Disarm** (Face ID) | when the alarm leaves `triggered` |
| 🔒 Alarm armed | any `armed_*` (toggle `notify_alarm_armed`), not sent for automatic changes (`timer.alarm_auto_disarm`) | both | passive | **Disarm** (Face ID) | replaced by the next alarm status push |
| 🔓 Alarm disarmed | `disarmed` (toggle `notify_alarm_disarmed`), not sent for automatic changes (`timer.alarm_auto_disarm`) | both | passive | none | replaced by the next alarm status push |
| Alarm not armed | everyone left while guest mode is on, so the automatic arm was skipped | Jeff | passive | none | replaced by the next one |
| Suspicious activity | disarmed between 00:00 and 05:00 | Jeff | time-sensitive | none | |
| Alarm disarmed while away | panel goes `disarmed` while nobody is home (not for automatic disarms) | Jeff | time-sensitive | none | |
| Alarm did not arm | midnight or everyone-leaves auto-arm was attempted but the panel is not armed after 1 min (silent if the toggle is off or guest mode skips the arm) | Jeff | time-sensitive | none | |
| 💦 Water detected | basement or sump sensor wet; repeats every 10 min while wet | both + Discord (once) | critical | **Silence 1 h** | replaced by "✅ Water cleared" when dry |
| 🚗 Garage door open | a door opens (`notify_garage_doors_home`; the away case needs `notify_garage_doors_away`) | Jeff when someone is home, both when nobody is | active (home) / time-sensitive (away) | **Close** | when the door closes |
| 🚗 Garage still open | everyone leaves with a door open | both | time-sensitive | **Close** | when the door closes |
| 🚗 Garage open 2 h | weekdays, door open 2 h, repeats every 3 h; also auto-closes if that door's toggle is on | both | time-sensitive | **Close**, **Snooze 2 h** (skips the push and the auto-close) | when the door closes |
| 🚗 Garage auto-close | 22:00 with `auto_garage_doors_night` on | both | time-sensitive | **Open again** | stays |
| 🚪 / 🪟 / 🏃 Sensor opened or motion while away | 15 alarm sensors while nobody is home | Jeff | time-sensitive | **Snooze 1 h** (that sensor only) | when the sensor closes |
| 🚪 / 🪟 Left open | 6 doors open for 5 minutes | both | time-sensitive | **Snooze 1 h** | when the door closes |
| 🔔 Doorbell | Dahua ring or button (30 s cooldown) | both | time-sensitive | **Live view** | |
| Doorbell listener stopped | no Dahua events for 6 h | Jeff | time-sensitive | none | |
| 🔋 Leak sensor battery low | a leak sensor drops below 30 %, then Sundays 09:00 while it stays low | Jeff | active | none | replaced by the next one |
| Printer toner low | a Brother cartridge drops below 15 % | Jeff | passive | none | |
| 🧊 Fridge door open | a fridge or freezer door open for 3 min | Jeff | time-sensitive | none | when the door closes |
| 🧊 Fridge water filter | 14 days or less left | Jeff | passive | none | |
| 🥶 Freeze coming | `sensor.forecast_low_2_nights` crosses below 28 °F (once per cold snap) | Jeff | passive | none | |
| 🔌 Plug in the car | 21:00, a car is home, unplugged and under 50 % | Jeff | active | none | |
| 🚗 Elektra open or unlocked | Elektra at home with a door, frunk or trunk open for 10 min, or unlocked at 23:30 | Jeff | time-sensitive | none | |
| 🛞 Tire pressure | a car reports a soft tire for 10 min | Jeff | active | none | |
| AlarmDecoder reconnected | panel stopped reporting; integration reloaded | Jeff | time-sensitive | none | |
| 🏠 Someone came home | `zone.home` goes above 0 | Jeff | passive | none | |
| 🏠 Jen came home | Jen's person entity becomes `home` | Jeff | active | none | |
| New device detected | a new `device_tracker` entity appears | Jeff | passive | none | |
| Camera detections | Frigate person, dog or cat on one of 5 cameras (rules below) | both | time-sensitive (porch, doorbell, pool) / active (driveway, front) | Mute 1 h; tapping opens that camera's live view (`/lovelace/camera-<name>`) | |

**Camera rules** (one automation per camera, all gated by `input_boolean.camera_<name>_notify`): porch and pool notify 22:00-05:59 or when nobody is home; front notifies on weekdays or when nobody is home, driveway only when nobody is home or on weekdays 09:30-15:00, both with a 2 min cooldown; the doorbell camera always notifies.

**Guest mode** (`input_boolean.guest_mode`, auto-off after 72 h via `timer.guest_mode`): `sensor.anyone_home` reads `home`, so the "opened/motion while nobody is home" pushes don't fire; the porch and pool camera pushes are muted; automatic alarm arming is blocked. The midnight `script.lights_off` leaves the basement lights (bedroom, living room, hallway, stairs) on. The downstairs Nest stays out of eco when everyone leaves. Left on in guest mode: the "left open" timeout pushes, the alarm armed/disarmed/triggered pushes, the other cameras. It sends a passive "Guest mode turned off" push to Jeff when the timer expires.

## Look

`script.notify_phones` picks an avatar (mdi icon and color) from the push's `group`; a caller can override `icon` or `color`. iOS shows it as a messaging-style notification, with the title as the sender.

| Group | Icon | Color |
|---|---|---|
| alarm | shield (lock when armed, off when disarmed, alert when triggered) | red |
| garage | garage | orange |
| water | water-alert | blue |
| doorbell | doorbell | purple |
| security | door-open (motion-sensor for motion) | amber |
| presence | home-account | green |
| network | wifi-alert | gray |
| cameras (blueprint) | person, dog, cat or cctv | teal |

Pushes in the same group stack together on the Lock Screen (iOS Notification Grouping is set to Automatic). A push with a `tag` replaces the previous one with that tag, and `script.notify_clear` removes it.

## Adding or changing a notification

Call the script instead of `notify.mobile_app_*`:

```yaml
- action: script.notify_phones
  data:
    audience: all            # all (default), jeff or jen
    title: "🚗 Garage"
    message: "The door is open"
    level: time-sensitive    # passive, active, time-sensitive or critical
    group: garage            # sets the avatar and the Lock Screen stack
    tag: garage_jeff         # a later push with this tag replaces it
    url: /lovelace/home      # where a tap goes
    actions:
      - action: "GARAGE_CLOSE|jeff"
        title: Close
        icon: "sfsymbols:arrow.down.to.line"
```

Other optional fields: `subtitle`, `sound`, `image`, `icon`, `color`.

### Action buttons

Button ids are `KIND|arg|arg` strings. The handler ignores ids it doesn't know (the Frigate blueprint uses its own).

| Id | Does |
|---|---|
| `DISARM_ALARM` | disarms the alarm panel (button should set `authenticationRequired: true`) |
| `GARAGE_OPEN\|jeff\|jen`, `GARAGE_CLOSE\|jeff\|jen` | opens / closes that door |
| `GARAGE_SNOOZE\|jeff\|jen\|<min>` | starts `timer.garage_<name>_snooze` |
| `SENSOR_SNOOZE\|<key>\|<min>` | starts `timer.snooze_<key>` (key = sensor id after `ser2sock_10000_`) |
| `CAMERA_MUTE\|<camera>\|<min>` | turns the camera's toggle off and starts `timer.camera_<camera>_mute`; `camera_mute_finished` turns it back on |
| `WATER_SILENCE\|all\|<min>` | starts `timer.water_alert_snooze` |

The timers use `restore: true`, so a snooze survives an HA restart.

## Testing

Set `input_boolean.notify_test_mode` on to send every `notify_phones` push to Jeff's phone only, or pass `audience: jeff` on a single call. Frigate camera pushes ignore test mode; to test one, set that instance's `notify_group` to `mobile_app_jeffsphone` and put it back to `ALL_DEVICES` afterwards.

## Not used

Live Activities (a Lock Screen card with a timer) work on this setup, but none are configured. A trial for the garage-open timer was tried and not kept.
