# Troubleshooting

## The Mac asks for Screen Recording repeatedly

- Keep only one installed copy of `DeskWeave.app`.
- Move it to `/Applications` before granting permission.
- Open **System Settings → Privacy & Security → Screen Recording** and enable
  DeskWeave.
- Quit and reopen the app after changing permission.

## No address appears on the Mac

- Confirm Wi-Fi is connected.
- Disable VPN software temporarily.
- Make sure DeskWeave has Local Network permission.

## Android cannot connect

- Confirm both devices use the same Wi-Fi network.
- Enter the complete address, including `:5900`.
- Avoid guest Wi-Fi or access points with client isolation.
- Check the macOS firewall prompt and allow incoming connections.
- Do not use a public internet address.

## The tablet is black

- Confirm the Android statistics show received and displayed frames.
- Open **System Settings → Displays** on the Mac and arrange the virtual
  display.
- Drag a visible window onto the virtual display; a new extended desktop can
  initially appear empty.
- Update both applications to the same protocol version.

## Low FPS on a static desktop

ScreenCaptureKit can send fewer frames when nothing changes. Move a window or
play a video before measuring frame rate.

## Stuttering

- Prefer 5 GHz or 6 GHz Wi-Fi with a strong signal.
- Keep the Mac and tablet near the access point.
- Stop large downloads and network backups.
- Disable battery-saving mode on the tablet.
- Compare `received`, `displayed`, and `dropped` statistics to determine whether
  the bottleneck is network delivery or decoding.

## The virtual display does not exist

DeskWeave depends on a private API. If `CGVirtualDisplay` is unavailable after
a macOS update, collect the exact macOS version and open a compatibility issue.

