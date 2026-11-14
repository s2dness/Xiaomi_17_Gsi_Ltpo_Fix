#!/system/bin/sh
# Xiaomi 17 GSI - Hz monitor v2.8
# Writes 3 values to a state file: Panel Hz (real LTPO, 1-9 Hz) | Mode Hz (SurfaceFlinger) | SF frame rate
MODDIR="/data/adb/modules/xiaomi17_gsi_ltpo_fix"
STATE_FILE="$MODDIR/.hz_enabled"
PID_FILE="$MODDIR/.hz_pid"
NOW_FILE="$MODDIR/.hz_now"

echo $$ > "$PID_FILE"

# 12.0 -> 12 | 3.46 -> 3.4 | 0 -> 0.0 | empty -> ?
fmt() {
    V="$1"
    if [ -z "$V" ]; then echo "?"; return; fi
    INT="${V%%.*}"
    [ -z "$INT" ] && INT=0
    FR=""
    case "$V" in
        *.*) FR=$(echo "${V#*.}" | cut -c1) ;;
    esac
    if [ "$INT" -ge 10 ] 2>/dev/null || [ -z "$FR" ]; then
        echo "$INT"
    else
        echo "$INT.$FR"
    fi
}

# 2.97 -> 3 | 0.4 -> 0 | 120.0 -> 120 | empty -> ?
round_int() {
    V="$1"
    if [ -z "$V" ] || [ "$V" = "?" ]; then echo "?"; return; fi
    INT="${V%%.*}"
    [ -z "$INT" ] && INT=0
    FR=0
    case "$V" in
        *.*) FR=$(echo "${V#*.}" | cut -c1) ;;
    esac
    [ -z "$FR" ] && FR=0
    [ "$FR" -ge 5 ] 2>/dev/null && INT=$(( INT + 1 ))
    echo "$INT"
}

now_ms() {
    T=$(date +%s%N 2>/dev/null)
    case "$T" in
        ""|*N*) echo $(( $(date +%s) * 1000 )) ;;
        *) echo $(( T / 1000000 )) ;;
    esac
}

# --- Find the real panel Hz node (once, at start) ---
mount -t debugfs none /sys/kernel/debug >/dev/null 2>&1

pick_node() {
    for NAME in measured_fps panel_fps current_fps current_refresh_rate dynamic_fps; do
        for D in /sys/class/drm /sys/class/mi_display /sys/devices/virtual/mi_display /sys/class/graphics /sys/kernel/debug/dri; do
            [ -d "$D" ] || continue
            for N in $(find -L "$D" -maxdepth 4 -name "$NAME" 2>/dev/null); do
                if [ -r "$N" ]; then
                    V=$(timeout 1 head -n 1 "$N" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?' | head -n 1)
                    if [ -n "$V" ]; then
                        echo "$N"
                        return
                    fi
                fi
            done
        done
    done
}

read_node() {
    [ -n "$NODE" ] || return
    timeout 1 head -n 1 "$NODE" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?' | head -n 1
}

# SurfaceFlinger active mode Hz
mode_hz() {
    M=$(echo "$SF_LINES" | grep -i 'activeMode' | grep -m1 -oE 'vsyncRate=[0-9.]+' | cut -d= -f2)
    if [ -n "$M" ]; then fmt "$M"; return; fi
    P=$(echo "$SF_LINES" | grep -m1 -oE 'vsyncPeriod=[0-9]+' | cut -d= -f2)
    if [ -n "$P" ] && [ "$P" -gt 0 ] 2>/dev/null; then
        echo $(( (1000000000 + P / 2) / P ))
        return
    fi
    echo "?"
}

# Total frame counter from SurfaceFlinger (TimeStats)
sf_total() {
    dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 2>/dev/null | grep -m1 -oE 'totalFrames = [0-9]+' | grep -oE '[0-9]+'
}

# Optional 3rd on-screen indicator (Hz Overlay app)
OVL_PKG="com.lifeispoop.hzoverlay"
OVL=0
pm list packages "$OVL_PKG" 2>/dev/null | grep -q "$OVL_PKG" && OVL=1

push_overlay() {
    am broadcast -a "$OVL_PKG.UPDATE" -p "$OVL_PKG" --es panel "$1" >/dev/null 2>&1
}

. "$MODDIR/profile.sh"
load_profile

# --- Experimental auto video match (hz autovideo) ---
# Apps that do not tell Android their video fps (many anime apps) stay at 120 Hz. When the SF
# frame rate stays at ~24/30 fps for a few seconds, lock the display to the lowest supported
# mode that is an exact multiple of it (24 -> 24/48/72/96/120), and unlock when UI activity returns.
RATES=$( { dumpsys SurfaceFlinger 2>/dev/null | grep -oE 'vsyncRate=[0-9.]+' | cut -d= -f2; \
           dumpsys display 2>/dev/null | grep -oE 'fps=[0-9.]+' | cut -d= -f2; } | cut -d. -f1 | sort -un | grep -E '^[0-9]+$')
FORCED=0
VID_N=0
OUT_N=0

pick_rate() {
    for R in $RATES; do
        [ "$R" -ge 20 ] 2>/dev/null || continue
        [ $(( R % $1 )) -eq 0 ] && { echo "$R"; return; }
    done
}

unlock_rate() {
    settings put system min_refresh_rate "$HZ_MIN" >/dev/null 2>&1
    settings put system peak_refresh_rate 120.0 >/dev/null 2>&1
    FORCED=0
}

cleanup() {
    [ "$FORCED" != "0" ] && unlock_rate
    [ -n "$TOUCH_PID" ] && kill "$TOUCH_PID" >/dev/null 2>&1
    [ -n "$TOUCH_DEV" ] && pkill -f "getevent -c 1 $TOUCH_DEV" >/dev/null 2>&1
    dumpsys SurfaceFlinger --timestats -disable >/dev/null 2>&1
    rm -f "$PID_FILE" "$NOW_FILE" "$MODDIR/.hz_touch"
    exit 0
}
trap cleanup TERM INT

# always start from the profile values (in case an earlier run was killed while locked)
unlock_rate

# --- Touch watcher: unlock the video lock as soon as the screen is touched ---
TOUCH_FLAG="$MODDIR/.hz_touch"
TOUCH_PID=""
TOUCH_DEV=""
getevent -pl > /data/local/tmp/hz_ev.txt 2>/dev/null
CUR=""
while read -r L; do
    case "$L" in
        "add device"*) CUR=$(echo "$L" | sed 's/.*: //') ;;
        *ABS_MT_POSITION_X*) [ -z "$TOUCH_DEV" ] && TOUCH_DEV="$CUR" ;;
    esac
done < /data/local/tmp/hz_ev.txt
rm -f /data/local/tmp/hz_ev.txt
rm -f "$TOUCH_FLAG"
if [ -n "$TOUCH_DEV" ]; then
    ( while true; do getevent -c 1 "$TOUCH_DEV" >/dev/null 2>&1 && : > "$TOUCH_FLAG"; sleep 0.3; done ) &
    TOUCH_PID=$!
fi

dumpsys SurfaceFlinger --timestats -enable >/dev/null 2>&1
NODE=$(pick_node)

PREV_TOTAL=$(sf_total)
PREV_MS=$(now_ms)
LAST=""
CAND=""
CAND_N=0
SKIP=0

# remove any old status bar notification from earlier versions
su 2000 -c "cmd notification cancel 'ltpo_hz_live'" >/dev/null 2>&1
while [ -f "$STATE_FILE" ] || [ -f "$MODDIR/.autovideo" ]; do
    sleep 1
    SF_LINES=$(dumpsys SurfaceFlinger 2>/dev/null | grep -iE 'activeMode|Kernel idle timer|isKernelIdle|vsyncPeriod')
    MODE=$(mode_hz)

    IDLE=0
    echo "$SF_LINES" | grep -qiE 'Kernel idle timer:[[:space:]]*(active|expired)|isKernelIdle=[1t]' && IDLE=1

    # SF frame rate = (frame count delta) / elapsed time
    NOW=$(now_ms)
    TOTAL=$(sf_total)
    SFFPS="?"
    X10=""
    if [ -n "$TOTAL" ] && [ -n "$PREV_TOTAL" ]; then
        DT=$(( NOW - PREV_MS ))
        [ "$DT" -le 0 ] && DT=1000
        D=$(( TOTAL - PREV_TOTAL ))
        [ "$D" -lt 0 ] && D=0
        X10=$(( D * 10000 / DT ))
        SFFPS=$(fmt "$(( X10 / 10 )).$(( X10 % 10 ))")
    fi
    PREV_TOTAL="$TOTAL"
    PREV_MS="$NOW"

    # 3rd indicator: real panel Hz (integer: 1,2,3...)
    if [ -n "$NODE" ]; then
        PANEL=$(round_int "$(read_node)")
        SRC=$(basename "$NODE")
    else
        PANEL=$(round_int "$SFFPS")
        SRC="SF frames (no panel node)"
    fi

    echo "$PANEL|$MODE|$SFFPS|$SRC|$IDLE|$FORCED" > "$NOW_FILE"

    # Touch -> unlock immediately and wait for quiet before locking again
    if [ -f "$TOUCH_FLAG" ]; then
        rm -f "$TOUCH_FLAG"
        [ "$FORCED" != "0" ] && unlock_rate
        VID_N=0
    fi

    # Auto video match
    if [ -f "$MODDIR/.autovideo" ] && [ -n "$X10" ]; then
        if [ "$X10" -ge 200 ] && [ "$X10" -le 315 ]; then
            VID_N=$(( VID_N + 1 ))
            OUT_N=0
        else
            OUT_N=$(( OUT_N + 1 ))
            VID_N=0
        fi
        if [ "$FORCED" = "0" ] && [ "$VID_N" -ge 4 ]; then
            # 24 fps (<= 27.5 measured) -> 24 Hz, otherwise 30 Hz (YouTube gets exactly these)
            if [ "$X10" -le 275 ]; then TARGET=24; else TARGET=30; fi
            # cap the peak only; keep the profile floor (but never above the target)
            MIN_I="${HZ_MIN%%.*}"
            [ "$MIN_I" -gt "$TARGET" ] 2>/dev/null && MIN_I="$TARGET"
            settings put system min_refresh_rate "$MIN_I.0" >/dev/null 2>&1
            settings put system peak_refresh_rate "$TARGET.0" >/dev/null 2>&1
            FORCED="$TARGET"
        elif [ "$FORCED" != "0" ] && [ "$OUT_N" -ge 2 ]; then
            unlock_rate
            VID_N=0
        fi
    elif [ "$FORCED" != "0" ]; then
        unlock_rate
    fi

    # Push to the overlay only when the value changed. Every redraw wakes the LTPO panel,
    # so: confirm with 2 identical readings and skip 2 readings after our own update.
    if [ "$OVL" = "1" ]; then
        if [ "$SKIP" -gt 0 ]; then
            SKIP=$(( SKIP - 1 ))
            CAND=""
            CAND_N=0
        elif [ "$PANEL" != "$LAST" ]; then
            if [ "$PANEL" = "$CAND" ]; then
                CAND_N=$(( CAND_N + 1 ))
            else
                CAND="$PANEL"
                CAND_N=1
            fi
            if [ "$CAND_N" -ge 2 ]; then
                push_overlay "$PANEL"
                LAST="$PANEL"
                SKIP=2
                CAND=""
                CAND_N=0
            fi
        else
            CAND=""
            CAND_N=0
        fi
    fi
done

cleanup
