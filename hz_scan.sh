#!/system/bin/sh
# Scan for the sysfs node that reports the panel's real Hz
OUT=/sdcard/hz_scan.txt
mount -t debugfs none /sys/kernel/debug >/dev/null 2>&1

{
echo "== date: $(date)"
echo "== props"
getprop | grep -iE 'fps|refresh|dfps|idle|lfd|vrr|ltpo|panel'

echo "== drm / mi_display / graphics / debugfs (path = value)"
for D in /sys/class/drm /sys/class/mi_display /sys/devices/virtual/mi_display /sys/class/graphics /sys/kernel/debug/dri; do
    [ -d "$D" ] || continue
    find -L "$D" -maxdepth 5 -type f \( -iname '*fps*' -o -iname '*refresh*' -o -iname '*idle*' -o -iname '*vrr*' -o -iname '*lfd*' -o -iname '*panel_info*' \) 2>/dev/null | while read -r F; do
        V=$(timeout 1 head -c 120 "$F" 2>/dev/null | tr '\n' ' ')
        echo "$F = $V"
    done
done

echo "== soc (fps/refresh only)"
find -L /sys/devices/platform/soc -maxdepth 6 -type f \( -iname '*fps*' -o -iname '*refresh*' \) 2>/dev/null | head -n 40 | while read -r F; do
    V=$(timeout 1 head -c 120 "$F" 2>/dev/null | tr '\n' ' ')
    echo "$F = $V"
done

echo "== SurfaceFlinger"
dumpsys SurfaceFlinger 2>/dev/null | grep -iE 'activeMode|kernel idle|isKernelIdle|vsyncRate' | head -n 20

echo "== timestats"
dumpsys SurfaceFlinger --timestats -enable >/dev/null 2>&1
dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 2>/dev/null | grep -iE 'totalFrames|missedFrames'
} > "$OUT" 2>&1

cat "$OUT"
echo
echo "Saved to: $OUT"
