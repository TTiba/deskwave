# Publishing on GitHub

## Create the repository

Recommended repository name and description:

- **Name:** `DeskWeave`
- **Description:** `Use an Android tablet as a low-latency wireless extended display for an Apple Silicon Mac.`
- **Topics:** `macos`, `android`, `second-screen`, `virtual-display`, `swift`,
  `h264`, `screencapturekit`, `videotoolbox`, `mediacodec`

Initialize and publish only after reviewing author details and the license:

```zsh
cd outputs/DeskWeave
git init
git add .
git commit -m "Initial open-source release"
git branch -M main
git remote add origin git@github.com:YOUR_ACCOUNT/DeskWeave.git
git push -u origin main
```

Replace `YOUR_ACCOUNT` with the GitHub owner. This file intentionally does not
assume or embed a remote account.

## Repository settings

- enable Issues and Discussions;
- enable private vulnerability reporting;
- protect `main` and require the `Build` workflow;
- disable force pushes and branch deletion on `main`;
- add the repository description and topics above;
- use GitHub's MIT license detection;
- optionally enable Dependabot for Gradle and GitHub Actions.

## First release

Suggested tag: `v0.3.0-alpha.1`.

Attach release artifacts instead of committing them:

- `DeskWeave-macOS.zip` containing `DeskWeave.app`;
- `DeskWeave-Android.apk` signed with the maintainer's release key;
- SHA-256 checksums for both files.

The release notes must state that the macOS app is experimental, ad-hoc signed
unless the maintainer notarizes it, uses a private API, and that the stream is
not encrypted or authenticated.

