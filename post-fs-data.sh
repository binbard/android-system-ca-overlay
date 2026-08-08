#!/system/bin/sh
MODDIR=${0%/*}
TARGET=/apex/com.android.conscrypt/cacerts
WORKDIR=/data/adb/android-system-ca-overlay/cacerts

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cp -af "$TARGET"/. "$WORKDIR"/
for CERT in "$MODDIR"/system/etc/security/cacerts/*.[0-9]*; do
  [ -f "$CERT" ] || continue
  cp -af "$CERT" "$WORKDIR"/
done
chown -R root:root "$WORKDIR"
chmod 755 "$WORKDIR"
chmod 644 "$WORKDIR"/*
chcon -R u:object_r:system_file:s0 "$WORKDIR" 2>/dev/null
mount -o bind "$WORKDIR" "$TARGET"
