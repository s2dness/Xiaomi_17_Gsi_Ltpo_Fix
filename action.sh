#!/system/bin/sh
MODDIR="/data/adb/modules/xiaomi17_gsi_ltpo_fix"
STATE_FILE="$MODDIR/.hz_enabled"
PID_FILE="$MODDIR/.hz_pid"
OVL_PKG="com.lifeispoop.hzoverlay"

ovl_installed() {
    pm list packages "$OVL_PKG" 2>/dev/null | grep -q "$OVL_PKG"
}

# Install the overlay APK automatically if it was downloaded to the phone
ovl_try_install() {
    for A in /sdcard/Download/HzOverlay.apk /sdcard/Download/app-debug.apk /sdcard/HzOverlay.apk /sdcard/app-debug.apk; do
        if [ -f "$A" ]; then
            pm install -r "$A" >/dev/null 2>&1 && return 0
        fi
    done
    return 1
}

ovl_start() {
    appops set "$OVL_PKG" SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1
    am start-foreground-service -n "$OVL_PKG/.OverlayService" >/dev/null 2>&1 \
        || am start -n "$OVL_PKG/.MainActivity" >/dev/null 2>&1
}

ovl_stop() {
    am broadcast -a "$OVL_PKG.STOP" -p "$OVL_PKG" >/dev/null 2>&1
    am stopservice -n "$OVL_PKG/.OverlayService" >/dev/null 2>&1
}

stop_monitor() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$OLD_PID" ] && kill "$OLD_PID" >/dev/null 2>&1
        rm -f "$PID_FILE"
    fi
    dumpsys SurfaceFlinger --timestats -disable >/dev/null 2>&1
}

if [ -f "$STATE_FILE" ]; then
    # TURN OFF
    rm -f "$STATE_FILE"
    stop_monitor
    service call SurfaceFlinger 1034 i32 0 >/dev/null 2>&1
    su 2000 -c "cmd notification cancel 'ltpo_hz_live'" >/dev/null 2>&1
    ovl_installed && ovl_stop
    rm -f "$MODDIR/.hz_now"
    # keep the monitor alive if auto video match is on
    if [ -f "$MODDIR/.autovideo" ]; then
        sleep 1
        nohup sh "$MODDIR/hz_monitor.sh" >/dev/null 2>&1 &
    fi
    echo "=========================================="
    echo "  [OFF] Hz indicator disabled             "
    echo "=========================================="
else
    # TURN ON + refresh live VRR/video settings
    touch "$STATE_FILE"
    . "$MODDIR/profile.sh"
    load_profile
    settings put system min_refresh_rate "$HZ_MIN" >/dev/null 2>&1
    settings put system peak_refresh_rate 120.0 >/dev/null 2>&1
    cmd device_config put surface_flinger use_content_detection_for_refresh_rate true >/dev/null 2>&1
    cmd device_config put surface_flinger enable_frame_rate_override true >/dev/null 2>&1

    setprop debug.sf.show_refresh_rate_overlay_in_middle 0 >/dev/null 2>&1
    setprop debug.sf.show_refresh_rate_overlay_render_rate 1 >/dev/null 2>&1
    service call SurfaceFlinger 1034 i32 0 >/dev/null 2>&1
    service call SurfaceFlinger 1034 i32 1 >/dev/null 2>&1

    stop_monitor
    # remove the old status bar notification from earlier versions, if any
    su 2000 -c "cmd notification cancel 'ltpo_hz_live'" >/dev/null 2>&1

    ovl_installed || ovl_try_install
    if ovl_installed; then
        ovl_start
        sleep 1
    fi
    nohup sh "$MODDIR/hz_monitor.sh" >/dev/null 2>&1 &

    CD_STATUS=$(dumpsys SurfaceFlinger 2>/dev/null | grep -i "useContentDetection" | head -n 1 | xargs)
    echo "=========================================="
    echo "  [ON] Hz indicator enabled               "
    echo "=========================================="
    echo "- Top-left overlay (SF): display Hz + render fps (120 120 / 60 30)"
    if ovl_installed; then
        echo "- 3rd indicator (orange/green, panel Hz) is shown below the SF numbers"
        echo "  Move it with:  hz pos X Y   (dp, default 12 80)"
    else
        echo "- 3rd on-screen indicator: Hz Overlay app is NOT installed."
        echo "  Build it with GitHub (see hz-overlay-build.yml), save the APK as"
        echo "  /sdcard/Download/HzOverlay.apk and press Action again."
    fi
    echo "- Real panel Hz also in the WebUI page, or run:  hz now  /  hz watch"
    echo "- If the source shows 'SF frames', no panel node was found: run  hz scan"
    [ -n "$CD_STATUS" ] && echo "- Engine status: $CD_STATUS"
    echo "- Press the Action button again to turn it off."
fi
