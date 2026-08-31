# Changelog

## 0.3.1 - 2026-08-31

- Versioned the Wi-Fi stream as protocol `DW31` on both platforms.
- Moved the default listener to TCP port `5901` to avoid collisions with old
  DeskWeave builds and common screen-sharing services.
- Made the Mac build version and protocol visible in the main window.

All notable changes to DeskWeave are documented here.

The project follows [Semantic Versioning](https://semver.org/) while protocol
compatibility is still experimental.

## [0.3.0] - 2026-08-03

Initial public Wi-Fi release.

### Added

- DeskWeave public identity for macOS and Android;
- 1792 × 1120 virtual extended display at up to 60 fps;
- H.264 Main Profile Level 4.2 hardware pipeline;
- bounded-latency SSV2 TCP transport;
- Android decoder capability validation and stream statistics;
- English interface and Brazilian Portuguese documentation;
- GitHub Actions, issue forms, contribution and security documentation.

### Security

- Documented that SSV2 0.3 is unauthenticated and unencrypted and must remain
  on a trusted private network.
