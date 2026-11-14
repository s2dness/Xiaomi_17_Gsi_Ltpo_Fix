#!/system/bin/sh
# Refresh-rate profile (shared by post-fs-data.sh, service.sh, action.sh and the hz command)
# saver    = default: lowest power, 1 Hz floor, short timers (most Hz transitions)
# balanced = 10 Hz floor, medium timers
# smooth   = 30 Hz floor, long timers (fewest transitions -> least gray flicker)
HZ_PROFILE_FILE=/data/adb/xiaomi17_hz_profile

load_profile() {
    HZ_PROFILE=$(cat "$HZ_PROFILE_FILE" 2>/dev/null)
    case "$HZ_PROFILE" in
        smooth)   HZ_MIN=30.0; HZ_IDLE=1500; HZ_TOUCH=2000 ;;
        balanced) HZ_MIN=10.0; HZ_IDLE=800;  HZ_TOUCH=1000 ;;
        *)        HZ_PROFILE=saver; HZ_MIN=1.0; HZ_IDLE=400; HZ_TOUCH=800 ;;
    esac
}
