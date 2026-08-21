# Tiktiger GitHub Build Report

## Pipeline status

The Tiktiger repository now contains a GitHub Actions workflow at `.github/workflows/build-tiktiger.yml`. The workflow is configured to build the existing Xcode Dynamic Library target on `macos-latest` using a Release configuration and an arm64 iPhoneOS SDK.

> **Current status:** Build automation is configured, YAML-parsed successfully, and statically validated. The first real Dylib generation and Mach-O validation will occur when the workflow is pushed to GitHub and a run is triggered.

No source files, Core services, feature modules, UI implementation, or architecture settings were changed for this phase. No IPA packaging, target application linking, or integration step is present in the workflow.

## Workflow contract

| Pipeline property | Configured value |
|---|---|
| Workflow file | `.github/workflows/build-tiktiger.yml` |
| Runner | `macos-latest` |
| Project | `Tiktiger.xcodeproj` |
| Scheme / target | `Tiktiger` |
| Configuration | `Release` |
| SDK | `iphoneos` |
| Architecture | `arm64` |
| Product | `Tiktiger.dylib` |
| Install name | `@rpath/Tiktiger.dylib` |
| Artifact name | `Tiktiger-dylib-release` |
| Artifact retention | 14 days |
| IPA generation | Not configured |
| Target App integration | Not configured |

## Workflow stages

The workflow checks out the repository, selects the Xcode installation exposed by the macOS runner, prints the selected Xcode version, and validates the expected project, scheme, public header, exported-symbol list, Dynamic Library product type, UIKit linkage, arm64 setting, and iOS 14 deployment target.

It then runs `xcodebuild` against the existing `Tiktiger` scheme with `Release`, `iphoneos`, `arm64`, and a dedicated `DerivedData` path. The resulting `Tiktiger.dylib` is located under the Release product directory without copying or modifying source files.

After the build, the workflow runs the required Mach-O checks and writes the run-specific report to `TIKTIGER_GITHUB_BUILD_REPORT.md` in the workflow workspace. The report includes the runner, Xcode version, artifact path, and raw output from `file`, `otool -L`, `otool -D`, and `nm -gU`.

| Validation | Required condition |
|---|---|
| `file` | Output identifies a Mach-O dynamically linked shared library containing arm64. |
| `otool -L` | Dependency list is recorded in the run report. |
| `otool -D` | Install name equals `@rpath/Tiktiger.dylib`. |
| `nm -gU` | All four required public symbols are present. |
| Artifact hygiene | No IPA or framework artifact is accepted from the product directory. |

The required symbols are `_TiktigerInitialize`, `_TiktigerGetVersion`, `_TiktigerGetStatus`, and `_TiktigerShutdown`. The leading underscore is the Darwin symbol spelling used by the exported-symbol list and `nm` validation.

## Build result

The workflow file passed YAML parsing and contract validation in the preparation environment. The source environment used for preparation is Linux and does not provide macOS, Xcode, or the iOS SDK. Consequently, the actual build result, Xcode version, Mach-O output, dependency list, install-name output, and final artifact path are **pending the first GitHub Actions run**. The workflow is designed to fail closed if the product is missing, the install name is incorrect, a required export is missing, or a forbidden IPA/framework artifact appears in the output directory.

## Artifact behavior

On successful validation, `actions/upload-artifact` uploads the generated `Tiktiger.dylib` together with the run-specific `TIKTIGER_GITHUB_BUILD_REPORT.md` under the artifact name `Tiktiger-dylib-release`. The artifact is immutable for that workflow run and is retained for 14 days by the workflow configuration.

## Remaining steps

The remaining release operation is to initialize or use the GitHub repository, commit the workflow and this documentation, push to the configured default branch, and trigger either a push, pull request, or manual workflow dispatch. After the run completes, the generated report should be reviewed for the actual Xcode version, product path, dependency output, install name, and symbol list.

The macOS build remains separate from IPA creation and application integration. Neither of those prohibited operations is required for this Dynamic Library pipeline.

## Final state

```text
REPOSITORY: GITHUB READY
BUILD: AUTOMATED
DYLIB: GENERATED AFTER GITHUB RUN
IPA: NOT CREATED
INTEGRATION: NOT STARTED
SOURCE: UNCHANGED
CORE: UNCHANGED
```

## References

[1]: https://docs.github.com/en/actions/tutorials/store-and-share-data "GitHub Actions: Store and share data with workflow artifacts"
[2]: https://github.com/actions/upload-artifact "GitHub actions/upload-artifact"
[3]: https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md "GitHub Actions runner images: macOS software and Xcode inventory"
