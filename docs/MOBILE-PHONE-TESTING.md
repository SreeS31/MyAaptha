# MyAaptha Android phone preview

Prepared 24 October 2026. This is a debug APK for local testing, not a signed store release.

## Install and connect

1. Connect your Android phone to the same Wi-Fi as this computer.
2. Open **http://192.168.1.4:4320/** on the phone and download the APK.
3. Install the downloaded APK, allowing installation from that browser when Android requests it.
4. Open MyAaptha and sign in using your own application account. The build uses **http://192.168.1.4:4320** as its API base; do not enter localhost on the phone.

Direct download: **http://192.168.1.4:4320/downloads/myaaptha-android.apk**.
API connection check: **http://192.168.1.4:4320/api/auth/health**.

Keep the computer awake, the local preview services running, and both devices on the same trusted Wi-Fi. This development connection uses HTTP. An IP address change requires updating the debug network allowlist and rebuilding the phone APK. No router port forwarding is needed.

## If the page does not open

The current automation account could start the server but Windows denied permission to add an inbound firewall rule. If the phone cannot connect, open **PowerShell as administrator** on this computer and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\vighn\Projects\CircleNet\infrastructure\allow-phone-preview.ps1
```

This allows only Node's preview port 4320 from 192.168.1.0/24 over the Wi-Fi interface. It does not expose the database or other API ports. Guest Wi-Fi/client isolation or a phone VPN may also prevent local access.

To remove that firewall exception later, run as administrator:

```powershell
Remove-NetFirewallRule -Name MyAaptha-Phone-Preview-4320
```

## Restart the download/API bridge

With the normal local API running on port 8080, run from the project root:

```powershell
node infrastructure/phone-preview.cjs 192.168.1.4 4320
```

The bridge serves only the install page, the explicit APK path, and `/api/` requests. It supports HTTP streaming and API WebSocket upgrades; it does not serve the project directory or the web application. Download artifact: `.tools/phone-preview/myaaptha-android.apk`. Build log: `.tools/phone-preview/android-build.log`. The previous emulator APK is preserved separately in the same local artifact directory.

APK updated 25 October 2026 with the post options menu, emoji reactions and personal pins. Size: 223,071,968 bytes. SHA-256: `129c10006d08f6d2f34763a66d3e63176990cd4d361a20cb71ad2ec9c6520c40`. Artifact identity: `.tools/phone-preview/apk-identity.json`.

## Verification and limits

Local requests through the exact Wi-Fi address passed registration, login/logout, profile, timeline, relationships, settings, health dashboard, finance summary, renewal listing/create/delete, circle conversations, address book and upload policy. The test renewal was removed and reminders were disabled. Admin-only dashboard summary correctly rejected an ordinary account. Requests for private project files returned 404. Evidence: `.tools/phone-preview/api-smoke.json`.

These checks were made from the computer, not a physical phone. Installation, camera/microphone/contacts permissions, real calls, notifications and external-provider integrations still need device/provider verification. SMS, push, OAuth, AI and other provider-dependent flows are not all guaranteed active by these checks. Do not interpret this setup as release acceptance or all launch tasks completed.

iPhone cannot install an Android APK. Native iOS testing requires a signed iOS build and an Apple/Mac build setup; this download is Android-only.

Updated 26 October 2026: compact inline help, native page headers and storage summary. Debug testing APK; physical-device acceptance remains pending.

26 October design update: shared typography, compact controls and narrow/enlarged-text settings checks; physical-device acceptance is still pending.

27 October: current Wi-Fi host is 192.168.1.4. The refreshed APK embeds this API address. The preview blocks APK downloads when their recorded API address differs from the running bridge; physical-device acceptance is still pending.
