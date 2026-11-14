#!/system/bin/sh
# Bootloop protection: wait until the system and UI are fully up
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 15

# The Hz indicator always starts OFF after a reboot
rm -f /data/adb/modules/xiaomi17_gsi_ltpo_fix/.hz_enabled /data/adb/modules/xiaomi17_gsi_ltpo_fix/.hz_pid /data/adb/modules/xiaomi17_gsi_ltpo_fix/.hz_now

# Apply the selected profile (hz profile saver|balanced|smooth)
. /data/adb/modules/xiaomi17_gsi_ltpo_fix/profile.sh
load_profile
settings put system min_refresh_rate "$HZ_MIN"
settings put system peak_refresh_rate 120.0

# Force live content/video detection in SurfaceFlinger (30/60fps -> 60Hz)
cmd device_config put surface_flinger use_content_detection_for_refresh_rate true >/dev/null 2>&1
cmd device_config put surface_flinger enable_frame_rate_override true >/dev/null 2>&1
cmd device_config put surface_flinger set_idle_timer_ms "$HZ_IDLE" >/dev/null 2>&1
cmd device_config put surface_flinger set_touch_timer_ms "$HZ_TOUCH" >/dev/null 2>&1
cmd device_config put surface_flinger set_display_power_timer_ms 800 >/dev/null 2>&1
cmd device_config put display_manager min_refresh_rate_default "$HZ_MIN" >/dev/null 2>&1

# Auto video match is ON by default (turn off with: hz autovideo)
MOD=/data/adb/modules/xiaomi17_gsi_ltpo_fix
if [ ! -f /data/adb/xiaomi17_hz_autovideo_off ]; then
    touch "$MOD/.autovideo"
    nohup sh "$MOD/hz_monitor.sh" >/dev/null 2>&1 &
fi
