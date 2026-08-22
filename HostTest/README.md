# Tiktiger Host Test Environment

## Purpose

`HostTest` is a controlled, first-party host application and XCTest bundle for validating Tiktiger runtime contracts. It does not modify TikTok, does not link to a third-party application, and does not use the reference IPA.

The host test loads the verified `Tiktiger.dylib` as an embedded dynamic library in a standalone iOS test application with bundle identifier `com.tiktiger.hosttest`. The source tree intentionally contains no copied Dylib; CI copies the freshly built Dylib artifact into `HostTest/Tiktiger.dylib` only inside the macOS build workspace.

## Covered Lifecycle

The runner constructs the real in-repository host coordinator, presentation bridge, compatibility layer, diagnostics store, module manager, feature bootstrap, and Feature Binding adapter. It validates the following host-owned sequence:

> **Initialize → Ready → Video Entry → Dashboard Descriptor → Present acknowledgement → Close → Return to context → Shutdown**

It also validates compatibility rejection for an unsupported host version, bounded recovery, stable Dashboard and navigation contracts, binding health availability, and runtime diagnostics history.

## Running on macOS/Xcode

From the repository root, build the production Dylib first and copy the resulting artifact into the HostTest project workspace without committing it:

```sh
mkdir -p HostTest
cp DerivedData/Build/Products/Release-iphoneos/Tiktiger.dylib HostTest/Tiktiger.dylib
xcodebuild -list -project HostTest/HostTest.xcodeproj
xcodebuild test \
  -project HostTest/HostTest.xcodeproj \
  -scheme TiktigerHostTest \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath HostTest/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

The GitHub Actions host-test job performs the same preparation with the current Release Dylib output, selects an available iOS Simulator, runs `xcodebuild test`, and writes `HostTest/host-test-report.md`. A successful host test must report lifecycle, compatibility/recovery, binding/routes/diagnostics, and Dylib checks as passed.

## Safety Boundaries

The host test does not inspect private TikTok state, does not perform injection, does not install or modify the reference IPA, and does not present a target-app controller. Dashboard and route presentation remain host-owned contracts. Download behavior is not simulated: the host tests only the existing runtime and contract paths and does not create fake download completion or progress.
