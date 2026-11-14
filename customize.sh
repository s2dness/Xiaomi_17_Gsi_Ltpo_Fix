#!/system/bin/sh
ui_print "************************************************"
ui_print "  Xiaomi 17 GSI - LTPO & Video VRR Fix (v2.8)   "
ui_print "  by @Lifeispoop                                "
ui_print "************************************************"
ui_print "- Setting file permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/hz_monitor.sh" 0 0 0755
set_perm "$MODPATH/hz_scan.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/profile.sh" 0 0 0755
set_perm "$MODPATH/system/bin/hz" 0 2000 0755
ui_print "- Auto video match is ON by default (24/30 fps video -> 24/30 Hz)."
ui_print "- Installation complete! Please reboot."
