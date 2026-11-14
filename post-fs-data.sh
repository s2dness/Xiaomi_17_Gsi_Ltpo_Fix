#!/system/bin/sh
# Apply the idle/touch timers of the selected profile before SurfaceFlinger starts
MODDIR=${0%/*}
. "$MODDIR/profile.sh"
load_profile
command -v resetprop >/dev/null 2>&1 || exit 0
resetprop -n ro.surface_flinger.set_idle_timer_ms "$HZ_IDLE"
resetprop -n ro.surface_flinger.set_touch_timer_ms "$HZ_TOUCH"
resetprop -n vendor.display.idle_time "$HZ_IDLE"
resetprop -n vendor.display.idle_time_inactive "$HZ_IDLE"
