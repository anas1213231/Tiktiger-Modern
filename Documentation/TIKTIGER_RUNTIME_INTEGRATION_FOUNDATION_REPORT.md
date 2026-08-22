# Tiktiger Runtime Integration Foundation Report

## Executive Summary

Phase 29 activates the host-owned runtime experience above the existing Tiktiger integration contracts. The verified Video Action entry now has a runtime lifecycle that can initialize the host-owned runtime, enforce compatibility, request a Dashboard presentation descriptor, accept an explicit host presentation acknowledgement, close the presentation, return to the originating TikTok video context, and attempt bounded recovery after failed or degraded initialization.

The implementation remains a runtime contract layer rather than target-app injection. It does not create UIKit controllers, fake buttons, fake downloads, or private TikTok hooks. The host remains responsible for actual presentation and context navigation. The existing Download Engine, Core, UI modules, and Xcode workflow are unchanged.

> **Final status:** Runtime Integration = **VERIFIED**; Dylib = **VERIFIED**; Core = **UNCHANGED**.

## Source and Scope

The Phase 29 source commit is `75f8b7005d761ad9a833c5a911eaea9a3051af7d`. The implementation is limited to the existing TikTok Integration Bridge and Integration Diagnostics contracts/storage:

| File | Scope |
|---|---|
| `Integration/TiktigerTikTokIntegrationBridge.h` | Adds runtime lifecycle states and host-owned initialize/start/present/close/return/recover contracts. |
| `Integration/TiktigerTikTokIntegrationBridge.m` | Implements runtime coordination over HostCoordinator, Compatibility, EntryPoint, PresentationBridge, and Diagnostics. |
| `Integration/TiktigerTikTokIntegrationDiagnostics.h` | Adds the runtime diagnostics recording contract. |
| `Integration/TiktigerTikTokIntegrationDiagnostics.m` | Adds bounded, redacted, immutable runtime history storage. |

No changes were made to `Core/`, `Features/`, `UI/`, `UIBridge/`, `Tiktiger.xcodeproj`, `.github/workflows/`, the Download Engine, or any target application.

## Runtime Lifecycle

The runtime lifecycle is represented by an explicit state machine and is owned by the existing host coordinator boundary.

| Runtime state | Meaning |
|---|---|
| `idle` | No runtime experience is active. |
| `initializing` | Host initialization has been requested. |
| `ready` | Host coordinator reached the existing runtime-ready state. |
| `presenting` | Video entry and Dashboard descriptor have passed validation; the host may present. |
| `presented` | The host explicitly acknowledged presentation completion. |
| `closing` | The host requested closure of the Dashboard experience. |
| `returned-to-context` | The host acknowledged return to the originating TikTok video context. |
| `recovering` | A bounded recovery attempt is in progress. |
| `failed` | Initialization, compatibility, dashboard descriptor, presentation acknowledgement, close, return, or recovery failed safely. |

The `initializeRuntimeWithArtifactMetadata:error:` contract delegates to the existing `TiktigerHostCoordinator`. It uses artifact preflight when metadata is provided and otherwise uses the existing public lifecycle initialization path. No second lifecycle owner was introduced.

## Video Entry Presentation

`startRuntimeExperienceForVideoContext:metadata:artifactMetadata:error:` is the runtime entry path. It initializes the runtime when required, then passes the context through the existing Video Action entry contract. The compatibility metadata is evaluated before the Dashboard descriptor is requested. Unsupported, unknown, unavailable, or failed compatibility states are returned as safe failure descriptors rather than being presented.

The successful path is:

> **Host runtime initialize → compatibility evaluation → Video Action context validation → Dashboard descriptor request → host presentation acknowledgement**

The returned descriptor includes the validated entry, Dashboard surface metadata, compatibility result, host presentation requirement, and runtime lifecycle state. It does not create a button or present a controller inside the dylib.

## Dashboard Launch and Presentation Ownership

The Dashboard is opened through the existing `TiktigerPresentationBridge dashboardPresentationEntry` contract. The runtime Bridge adds a lifecycle envelope around that descriptor but preserves the existing host-owned boundary.

| Presentation property | Verified value |
|---|---|
| Presentation mode | `host-owned` |
| Dylib controller creation | Not performed |
| Navigation execution marker | `not-performed` |
| Host acknowledgement | Explicit through `presentRuntimeExperienceForEntry:hostEvent:error:` |
| Target app integration | `NO` |
| Integration status | `foundation-only` |
| Runtime integration status | `host-owned-runtime-contract` |

A host presentation acknowledgement transitions the runtime state to `presented` and records a presentation and runtime diagnostic event. It does not claim that the dylib itself performed UIKit presentation.

## Close and Return-to-TikTok Context

`closeRuntimeExperienceWithReason:error:` records host closure, transitions to `closing`, and preserves active Download Engine tasks. It does not cancel, pause, or mutate Download Engine behavior.

`returnToTikTokRuntimeContext:hostEvent:error:` records the host return event, transitions to `returned-to-context`, clears the active runtime association, and preserves Download Engine tasks. The returned descriptor identifies the `video-context` return boundary and whether a host event was received.

The lifecycle is intentionally host-owned because the current repository does not link a target TikTok application or execute target-app navigation.

## Compatibility Enforcement

The runtime start path does not bypass `TiktigerTikTokCompatibility`. It uses the existing metadata evaluator and the existing five-profile policy: supported, supported-limited, unknown, unsupported, and error. The Video Action Entry contract receives the evaluated profile together with runtime readiness and navigation availability.

| Compatibility condition | Runtime behavior |
|---|---|
| Supported or supported-limited | Continue to validated Video Action and Dashboard descriptor. |
| Unknown | Return the existing safe availability/fallback descriptor. |
| Unsupported | Reject presentation safely and record failure. |
| Error or missing metadata | Reject safely and record compatibility/runtime failure. |

No TikTok private inspection, version scraping, hook, or unsupported source claim was added.

## Recovery

`recoverRuntimeWithArtifactMetadata:reason:error:` enters `recovering`, delegates to the existing `TiktigerHostCoordinator recoverHost:` bounded recovery path, records the result, and returns either `ready` or `failed`. Failed recovery clears the active runtime entry. Successful recovery does not automatically present a Dashboard or replay a Video Action; the host must request a new runtime experience explicitly.

This prevents automatic duplicate presentation and keeps recovery deterministic for long-running host sessions.

## Integration Diagnostics

`TiktigerTikTokIntegrationDiagnostics` now stores `runtimeHistory` alongside the existing entry, navigation, compatibility, presentation, and Download Flow histories. The same policy applies to every category:

| Policy | Verified behavior |
|---|---|
| Bounded | Maximum 32 events per category. |
| Redacted | Payloads pass through `TiktigerRedactedDiagnosticCopy`. |
| Immutable | Snapshots are returned as defensive copies. |
| Thread-safe | Storage is guarded by the existing diagnostics lock. |
| Target boundary | `targetAppIntegrated = NO`. |

Runtime diagnostics record initialize requested/completed/failed, presentation requested/completed/failed, close, return-to-context, recovery requested/completed/failed, and safe lifecycle rejection events.

## Architecture Compliance

The runtime flow remains within the established architecture:

> **Host event → Compatibility Layer → Entry Point Contract → Presentation Bridge → Host-owned presentation → Integration Diagnostics**

The existing HostCoordinator remains the single lifecycle owner for the loaded dylib. The Integration Bridge coordinates descriptors and lifecycle acknowledgements but does not take ownership of UIKit presentation, Download Engine execution, or target-app navigation.

## Static Validation

The Phase 29 static integration gate passed after the source commit. It verified runtime contracts, lifecycle state mappings, compatibility enforcement, bounded/redacted diagnostics, source-count stability, and protected scopes.

| Validation | Result |
|---|---|
| `git diff --check` | Pass |
| Runtime lifecycle contract coverage | Pass |
| Initialize/present/close/return/recover coverage | Pass |
| Compatibility enforcement marker | Pass |
| Runtime diagnostics history | Pass |
| Fake UI/button/download scan | Pass |
| Hook/legacy runtime scan | Pass |
| `targetAppIntegrated = NO` | Pass |
| `integrationStatus = foundation-only` | Pass |
| `presentationExecution = not-performed` | Pass |
| Compile sources | 60 |
| Core changes | None |
| Download Engine changes | None |
| UI changes | None |
| Workflow changes | None |

## GitHub Actions and Dylib Verification

GitHub Actions run `32539328358` completed successfully for source commit `75f8b7005d761ad9a833c5a911eaea9a3051af7d` on macOS using Xcode `26.6`. The workflow parsed the Xcode project, validated the Dynamic Library target, built the Release product, validated the Mach-O output, and uploaded the artifact.

| Build field | Verified value |
|---|---|
| Product | `Tiktiger.dylib` |
| Architecture | `arm64` |
| Deployment | iOS 14.0+ |
| Install name | `@rpath/Tiktiger.dylib` |
| Compile sources | 60 |
| Mach-O type | arm64 dynamically linked shared library |
| Required exports | `TiktigerInitialize`, `TiktigerGetVersion`, `TiktigerGetStatus`, `TiktigerShutdown` |
| Artifact SHA-256 | `340361a6e436bc5aaf0aa0b1d672440c9ab41c52734feb00449250476f5a688a` |

## Final Status

> **RUNTIME INTEGRATION = VERIFIED**
>
> **DYLIB = VERIFIED**
>
> **CORE = UNCHANGED**
>
> **TARGET APP INTEGRATION = NOT STARTED**

Phase 29 is complete. Tiktiger now exposes a verified host-owned runtime experience with explicit lifecycle, compatibility, recovery, and diagnostics contracts while preserving all existing product and architecture safeguards.
