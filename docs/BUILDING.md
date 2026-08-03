# Building from source

## macOS

### Requirements

- Apple Silicon Mac with macOS 15 or newer;
- Xcode Command Line Tools;
- Swift 6-compatible toolchain.

Install the command-line tools if necessary:

```zsh
xcode-select --install
```

Build and package the ad-hoc signed app:

```zsh
cd macOS/DeskWeaveMac
./build-app.sh
```

The script uses a stable designated requirement based on
`app.deskweave.mac`. This helps macOS associate rebuilt local versions with the
same Screen Recording permission entry. The output is not notarized.

To compile without packaging:

```zsh
swift build --package-path macOS/DeskWeaveMac --disable-sandbox
```

## Android

### Requirements

- JDK 17;
- Android SDK Platform 36;
- Android SDK Build Tools 36.0.0.

Build the debug APK:

```zsh
cd android/DeskWeaveAndroid
./gradlew assembleDebug lintDebug
```

For a distributable release, maintainers must configure their own protected
release keystore outside the repository. Never commit signing material or
passwords.

## Verification checklist

- macOS Swift package compiles;
- Swift test target compiles and its hardware test passes on a logged-in Mac;
- app bundle passes `codesign --verify --deep --strict`;
- Android `assembleDebug` succeeds;
- Android lint contains no errors;
- both applications report version 0.3.0;
- no build output or signing material appears in `git status`.
