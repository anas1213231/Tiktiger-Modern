#!/usr/bin/env python3
"""Production validation for the checked-out Tiktiger Xcode project.

The project.pbxproj is parsed first by Apple's plutil on the macOS runner. This
script only inspects the JSON representation emitted by that parser; it does
not implement a second permissive pbxproj parser.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(os.environ.get("GITHUB_WORKSPACE", Path.cwd())).resolve()
PROJECT_DIR = ROOT / "Tiktiger.xcodeproj"
PROJECT_FILE = PROJECT_DIR / "project.pbxproj"
SCHEME_FILE = PROJECT_DIR / "xcshareddata" / "xcschemes" / "Tiktiger.xcscheme"


def show(value: Any) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=False) if not isinstance(value, str) else value


def fail(path: Path | str, expected: str, detected: Any) -> "NoReturn":
    print("VALIDATION_FAILED", file=sys.stderr)
    print(f"path={path}", file=sys.stderr)
    print(f"expected={expected}", file=sys.stderr)
    print(f"detected={show(detected)}", file=sys.stderr)
    raise SystemExit(1)


def require_file(path: Path, expected: str | None = None) -> None:
    if not path.is_file():
        fail(path, expected or "existing regular file", "missing")


def require_directory(path: Path) -> None:
    if not path.is_dir():
        fail(path, "existing directory", "missing")


def run_plutil_json() -> dict[str, Any]:
    require_file(PROJECT_FILE, "Xcode project.pbxproj file")
    raw = PROJECT_FILE.read_text(encoding="utf-8", errors="replace")
    for marker in ("<<<<<<<", "=======", ">>>>>>>"):
        if marker in raw:
            fail(PROJECT_FILE, "no unresolved source-control conflict markers", marker)

    lint = subprocess.run(["plutil", "-lint", str(PROJECT_FILE)], text=True, capture_output=True)
    if lint.returncode != 0:
        fail(PROJECT_FILE, "valid OpenStep plist accepted by Apple's plutil", lint.stdout.strip() or lint.stderr.strip())

    with tempfile.TemporaryDirectory(prefix="tiktiger-pbx-json-") as temporary:
        json_file = Path(temporary) / "project.json"
        converted = subprocess.run(
            ["plutil", "-convert", "json", "-o", str(json_file), str(PROJECT_FILE)],
            text=True,
            capture_output=True,
        )
        if converted.returncode != 0 or not json_file.is_file():
            fail(PROJECT_FILE, "plutil JSON conversion succeeds", converted.stdout.strip() or converted.stderr.strip())
        try:
            data = json.loads(json_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(PROJECT_FILE, "JSON emitted by plutil is valid", str(error))
    if not isinstance(data, dict):
        fail(PROJECT_FILE, "top-level project plist is an object", type(data).__name__)
    return data


def objects_by_isa(objects: dict[str, Any], isa: str) -> list[tuple[str, dict[str, Any]]]:
    return [
        (identifier, value)
        for identifier, value in objects.items()
        if isinstance(value, dict) and value.get("isa") == isa
    ]


def object_or_fail(objects: dict[str, Any], identifier: str, context: str) -> dict[str, Any]:
    value = objects.get(identifier)
    if not isinstance(value, dict):
        fail(PROJECT_FILE, f"defined object reference for {context}", identifier)
    return value


def target_phase(objects: dict[str, Any], target: dict[str, Any], isa: str) -> dict[str, Any]:
    matches = []
    for phase_id in target.get("buildPhases", []):
        phase = object_or_fail(objects, phase_id, f"target build phase {phase_id}")
        if phase.get("isa") == isa:
            matches.append(phase)
    if len(matches) != 1:
        fail(PROJECT_FILE, f"exactly one {isa} for Tiktiger", len(matches))
    return matches[0]


def resolve_group_file_paths(objects: dict[str, Any], main_group_id: str) -> dict[str, str]:
    resolved: dict[str, str] = {}
    visited: set[str] = set()

    def visit(group_id: str, base: Path) -> None:
        if group_id in visited:
            fail(PROJECT_FILE, "acyclic PBXGroup graph", f"cycle at {group_id}")
        visited.add(group_id)
        group = object_or_fail(objects, group_id, f"group {group_id}")
        if group.get("isa") not in {"PBXGroup", "PBXVariantGroup"}:
            fail(PROJECT_FILE, "PBXGroup for mainGroup and group children", group.get("isa"))
        group_base = base
        if group_id != main_group_id and group.get("sourceTree") == "<group>" and group.get("path"):
            group_base = base / str(group["path"])
        for child_id in group.get("children", []):
            child = object_or_fail(objects, child_id, f"group child {child_id}")
            child_isa = child.get("isa")
            if child_isa in {"PBXGroup", "PBXVariantGroup"}:
                visit(child_id, group_base)
            elif child_isa == "PBXFileReference":
                source_tree = child.get("sourceTree")
                path_value = child.get("path") or child.get("name")
                if source_tree == "<group>" and path_value:
                    resolved[child_id] = (group_base / str(path_value)).as_posix()
                elif source_tree == "SOURCE_ROOT" and path_value:
                    resolved[child_id] = Path(str(path_value)).as_posix()
        visited.remove(group_id)

    visit(main_group_id, Path("."))
    return {identifier: path.removeprefix("./") for identifier, path in resolved.items()}


def build_file_names(objects: dict[str, Any], phase: dict[str, Any]) -> list[str]:
    names: list[str] = []
    for build_id in phase.get("files", []):
        build = object_or_fail(objects, build_id, f"PBXBuildFile {build_id}")
        ref_id = build.get("fileRef")
        ref = object_or_fail(objects, ref_id, f"file reference {ref_id}")
        names.append(str(ref.get("name") or ref.get("path") or ref_id))
    return names


def validate_repository_paths() -> None:
    for directory in (PROJECT_DIR, ROOT / "Core", ROOT / "Configuration", ROOT / "Diagnostics", ROOT / "Features", ROOT / "UI", ROOT / "UIBridge", ROOT / "Public"):
        require_directory(directory)
    require_file(SCHEME_FILE, "shared Tiktiger.xcscheme")
    require_file(ROOT / ".github" / "workflows" / "build-tiktiger.yml", "GitHub Actions workflow")
    require_file(ROOT / "Public" / "Tiktiger.h", "public Tiktiger header")
    require_file(ROOT / "Public" / "TiktigerExportedSymbols.txt", "exported symbols file")

    forbidden_suffixes = {".ipa", ".dylib", ".framework", ".xcarchive", ".a", ".o", ".so"}
    forbidden_paths = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or not path.is_file():
            continue
        if path.suffix.lower() in forbidden_suffixes:
            forbidden_paths.append(path.relative_to(ROOT).as_posix())
    if forbidden_paths:
        fail(ROOT, "no generated IPA/Dylib/framework/binary artifacts in checkout", forbidden_paths)


def validate_scheme(target_id: str) -> None:
    try:
        tree = ET.parse(SCHEME_FILE)
    except (ET.ParseError, OSError) as error:
        fail(SCHEME_FILE, "valid Xcode scheme XML", str(error))
    references = tree.findall(".//BuildableReference")
    matches = [reference for reference in references if reference.get("BlueprintName") == "Tiktiger"]
    if len(matches) != 1:
        fail(SCHEME_FILE, "exactly one BuildableReference BlueprintName=Tiktiger", [reference.attrib for reference in references])
    reference = matches[0]
    expected = {
        "BlueprintIdentifier": target_id,
        "BlueprintName": "Tiktiger",
        "BuildableName": "Tiktiger.dylib",
        "BuildableIdentifier": "primary",
    }
    for key, expected_value in expected.items():
        detected = reference.get(key)
        if detected != expected_value:
            fail(SCHEME_FILE, f"{key}={expected_value}", detected)


def validate_project(data: dict[str, Any]) -> None:
    objects = data.get("objects")
    if not isinstance(objects, dict):
        fail(PROJECT_FILE, "objects dictionary", type(objects).__name__)

    projects = objects_by_isa(objects, "PBXProject")
    if len(projects) != 1:
        fail(PROJECT_FILE, "exactly one PBXProject object", len(projects))
    project_id, project = projects[0]
    root_object = data.get("rootObject")
    if root_object != project_id:
        fail(PROJECT_FILE, f"rootObject={project_id}", root_object)

    targets = objects_by_isa(objects, "PBXNativeTarget")
    if len(targets) != 1:
        fail(PROJECT_FILE, "exactly one PBXNativeTarget", len(targets))
    target_id, target = targets[0]
    for key, expected in (("name", "Tiktiger"), ("productName", "Tiktiger"), ("productType", "com.apple.product-type.library.dynamic")):
        detected = target.get(key)
        if detected != expected:
            fail(PROJECT_FILE, f"Tiktiger target {key}={expected}", detected)
    if target.get("dependencies") not in ([], None):
        fail(PROJECT_FILE, "Tiktiger target has no target dependencies", target.get("dependencies"))

    product_reference_id = target.get("productReference")
    product_reference = object_or_fail(objects, product_reference_id, "Tiktiger product reference")
    product_name = product_reference.get("name") or product_reference.get("path")
    if product_name != "Tiktiger.dylib":
        fail(PROJECT_FILE, "product reference name/path=Tiktiger.dylib", product_name)

    config_list_id = target.get("buildConfigurationList")
    config_list = object_or_fail(objects, config_list_id, "Tiktiger target configuration list")
    config_ids = config_list.get("buildConfigurations")
    configs = [object_or_fail(objects, config_id, f"configuration {config_id}") for config_id in config_ids or []]
    config_names = sorted(str(config.get("name")) for config in configs)
    if config_names != ["Debug", "Release"]:
        fail(PROJECT_FILE, "target Debug and Release configurations", config_names)

    required_settings = {
        "PRODUCT_NAME": "Tiktiger",
        "EXECUTABLE_SUFFIX": ".dylib",
        "MACH_O_TYPE": "mh_dylib",
        "LD_DYLIB_INSTALL_NAME": "@rpath/Tiktiger.dylib",
        "SDKROOT": "iphoneos",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.tiktiger.runtime",
        "EXPORTED_SYMBOLS_FILE": "$(SRCROOT)/Public/TiktigerExportedSymbols.txt",
    }
    for config in configs:
        settings = config.get("buildSettings")
        if not isinstance(settings, dict):
            fail(PROJECT_FILE, f"buildSettings dictionary for {config.get('name')}", settings)
        architectures = settings.get("ARCHS")
        architecture_values = architectures if isinstance(architectures, list) else [architectures]
        if architecture_values != ["arm64"]:
            fail(PROJECT_FILE, f"ARCHS=arm64 for {config.get('name')}", architectures)
        deployment = settings.get("IPHONEOS_DEPLOYMENT_TARGET")
        try:
            deployment_number = float(str(deployment))
        except (TypeError, ValueError):
            deployment_number = -1
        if deployment_number < 14.0:
            fail(PROJECT_FILE, f"IPHONEOS_DEPLOYMENT_TARGET>=14.0 for {config.get('name')}", deployment)
        for key, expected in required_settings.items():
            detected = settings.get(key)
            if detected != expected:
                fail(PROJECT_FILE, f"{key}={expected} for {config.get('name')}", detected)

    main_group_id = project.get("mainGroup")
    if not main_group_id:
        fail(PROJECT_FILE, "PBXProject mainGroup reference", main_group_id)
    resolved_files = resolve_group_file_paths(objects, main_group_id)

    source_phase = target_phase(objects, target, "PBXSourcesBuildPhase")
    source_build_ids = source_phase.get("files") or []
    actual_sources = []
    for build_id in source_build_ids:
        build = object_or_fail(objects, build_id, f"source PBXBuildFile {build_id}")
        ref_id = build.get("fileRef")
        path = resolved_files.get(ref_id)
        if path is None:
            fail(PROJECT_FILE, "source file reference resolves inside repository", ref_id)
        actual_sources.append(path)
    expected_sources = sorted(
        path.relative_to(ROOT).as_posix()
        for path in ROOT.rglob("*.m")
        if ".git" not in path.parts and "DerivedData" not in path.parts and "HostTest" not in path.parts
    )
    actual_sources = sorted(actual_sources)
    minimum_source_count = 37
    if len(expected_sources) < minimum_source_count:
        fail(ROOT, f"at least {minimum_source_count} Objective-C implementation files in the current source tree", len(expected_sources))
    if actual_sources != expected_sources:
        fail(PROJECT_FILE, "Compile Sources exactly match all production repository .m files (HostTest excluded)", actual_sources)

    frameworks_phase = target_phase(objects, target, "PBXFrameworksBuildPhase")
    frameworks = build_file_names(objects, frameworks_phase)
    if frameworks != ["UIKit.framework"]:
        fail(PROJECT_FILE, "Frameworks phase contains UIKit.framework only", frameworks)

    resources_phase = target_phase(objects, target, "PBXResourcesBuildPhase")
    resources = resources_phase.get("files") or []
    if resources:
        fail(PROJECT_FILE, "Resources phase is empty for this source-only Dynamic Library", resources)

    validate_scheme(target_id)

    source_extensions = {".h", ".m"}
    prohibited_terms = re.compile(r"Substrate|Theos|Logos|MSHook|fishhook|method_exchangeImplementations|dlopen|dlsym")
    source_roots = [ROOT / name for name in ("Core", "Configuration", "Diagnostics", "Features", "UI", "UIBridge", "Public")]
    for source_root in source_roots:
        for path in source_root.rglob("*"):
            if path.is_file() and path.suffix in source_extensions:
                content = path.read_text(encoding="utf-8", errors="replace")
                match = prohibited_terms.search(content)
                if match:
                    fail(path, "no legacy hook/injection terms in source files", match.group(0))

    print("VALIDATION_PASS")
    print(f"repository={ROOT}")
    print(f"project={PROJECT_FILE}")
    print(f"scheme={SCHEME_FILE}")
    print(f"target={target.get('name')}")
    print("native_targets=1")
    print("product_type=com.apple.product-type.library.dynamic")
    print("product=Tiktiger.dylib")
    print(f"compile_sources={len(expected_sources)}")
    print("frameworks=UIKit.framework")
    print("resources=EMPTY")
    print("architecture=arm64")
    print("deployment=iOS14.0+")
    print("install_name=@rpath/Tiktiger.dylib")
    print("legacy_source_terms=NONE")


def main() -> None:
    validate_repository_paths()
    data = run_plutil_json()
    validate_project(data)


if __name__ == "__main__":
    main()
