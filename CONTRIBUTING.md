# Contributing to DeskWeave

Thank you for helping improve DeskWeave. Small, focused changes are easiest to
review and test across real Android hardware.

## Before opening an issue

- Search existing issues.
- Read [Troubleshooting](docs/TROUBLESHOOTING.md).
- Do not post private IP addresses, device serial numbers, signing files, or
  other sensitive information.
- For vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of opening a
  public issue.

## Bug reports

Include:

- Mac model and exact macOS version;
- tablet model and Android version;
- DeskWeave version on both devices;
- whether the virtual display appears in macOS Display settings;
- received, displayed, dropped FPS and bitrate shown on Android;
- reproducible steps and relevant logs.

## Pull requests

1. Keep Wi-Fi behavior backward compatible unless the change explicitly
   versions the protocol.
2. Do not add third-party dependencies without explaining the need.
3. Run the macOS and Android builds described in [Building](docs/BUILDING.md).
4. Update documentation for user-visible behavior.
5. Avoid committing generated apps, APKs, build folders, signing material, or
   machine-specific paths.

By contributing, you agree that your contribution is licensed under the MIT
License.

