# Android System CA Overlay for rooted Android 14+

This KernelSU module installs one or more PEM CA certificates into Android's active system trust store. It is designed for Android versions that use the Conscrypt APEX store, including Android 16. mitmproxy is used below as an example certificate source.

The module does not modify `/system` or the Conscrypt APEX on disk. At boot it copies the stock CA store, adds the module certificates, and bind-mounts the combined store over `/apex/com.android.conscrypt/cacerts`.

## Requirements

- `adb` and OpenSSL available on the computer.
- A connected Android device with root and KernelSU/Magisk-style module support.
- mitmproxy started once, so that `mitmproxy-ca-cert.pem` exists. Its default location on Windows is `%USERPROFILE%\.mitmproxy\mitmproxy-ca-cert.pem`.

## Prepare a certificate

Android system CA filenames use OpenSSL's legacy subject hash. From the directory containing `mitmproxy-ca-cert.pem`, run:

```powershell
$hash = openssl x509 -inform PEM -subject_hash_old -in .\mitmproxy-ca-cert.pem -noout
Copy-Item .\mitmproxy-ca-cert.pem ".\android-system-ca-overlay\system\etc\security\cacerts\$hash.0"
```

The command produces a name such as `c8750f0d.0`. The script is not hardcoded to that value: it installs every PEM file in `system/etc/security/cacerts` whose filename ends in Android's numbered hash suffix, such as `.0` or `.1`. If two certificates have the same subject hash, name them `.0`, `.1`, and so on.

## Install or update the module

From the directory containing `android-system-ca-overlay`:

```powershell
adb devices
adb shell id
adb push .\android-system-ca-overlay /data/adb/modules/
adb shell chown -R root:root /data/adb/modules/android-system-ca-overlay
adb shell chmod 755 /data/adb/modules/android-system-ca-overlay/post-fs-data.sh
adb reboot
adb wait-for-device
```

The device must report `uid=0(root)` before installing. Reboot is required because the module mounts the CA store during boot.

## Verify installation

Use the certificate hash printed during preparation:

```powershell
adb shell ls -l /apex/com.android.conscrypt/cacerts/<hash>.0
adb shell toybox sha256sum /apex/com.android.conscrypt/cacerts/<hash>.0
Get-FileHash .\mitmproxy-ca-cert.pem -Algorithm SHA256
```

The two SHA-256 values must match. The active system CA path on this device is `/apex/com.android.conscrypt/cacerts`.

## Proxy and HTTPS test

Run mitmproxy locally and use ADB reverse to make the computer's loopback proxy available as the device's loopback proxy:

```powershell
mitmdump --listen-host 127.0.0.1 --listen-port 8080
adb reverse tcp:8080 tcp:8080
adb shell settings put global http_proxy 127.0.0.1:8080
```

In another terminal, test through the proxy using the active Android CA directory:

```powershell
adb shell curl -x http://127.0.0.1:8080 --capath /apex/com.android.conscrypt/cacerts -I https://example.com
```

Success shows both `HTTP/1.1 200 Connection established` and an upstream `HTTP/1.1 200 OK`. mitmproxy should display the intercepted request.

Clean up the temporary proxy configuration after testing:

```powershell
adb shell settings delete global http_proxy
adb reverse --remove tcp:8080
```

## Notes and limitations

- The device's standalone `curl` uses a separate default CA configuration, so `--capath` is needed for this command-line test. Android apps that use the platform trust store use the installed CA automatically.
- Certificate-pinned apps can still reject interception even when the CA is trusted.
- If the device's Android version uses a different active CA path, inspect `/apex/com.android.conscrypt/cacerts` and `/system/etc/security/cacerts` before installing.
- Remove or disable the `android-system-ca-overlay` module in the KernelSU manager to uninstall it, then reboot.
