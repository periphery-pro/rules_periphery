#!/usr/bin/env python3
"""Check resource inputs and the Core Data interface expected by older CLIs."""

import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

args = sys.argv[1:]
# Like the CLI, use the workspace root for bazel run unless a project root
# is explicitly supplied (as it is by scan_test).
if "BUILD_WORKSPACE_DIRECTORY" in os.environ and "--project-root" not in args:
    os.chdir(os.environ["BUILD_WORKSPACE_DIRECTORY"])
config = json.loads(Path(args[args.index("--generic-project-config") + 1]).read_text())
models = [Path(path) for path in config["xcdatamodels"]]
mappings = [Path(path) for path in config["xcmappingmodels"]]
assert len(models) == len(set(models)) == 5, models
assert len(mappings) == 2, mappings

# Match the old parsers: enumerate .xcdatamodel children of each model
# directory, and append xcmapping.xml to each mapping model directory.
references = set()
model_count = 0
for directory in models:
    for child in directory.iterdir():
        if child.suffix == ".xcdatamodel":
            model_count += 1
            model = ET.parse(child / "contents")
            references.update(node.attrib["customClassName"] for node in model.iter() if "customClassName" in node.attrib)
assert model_count == 6, model_count
for directory in mappings:
    model = ET.parse(directory / "xcmapping.xml")
    references.update(node.text for node in model.iter() if node.attrib.get("name") == "migrationpolicyclassname")
assert references == {"CustomTransformer", "CustomMigrationPolicy"}, references

xibs = [Path(path) for path in config["xibs"]]
assert len(xibs) == len(set(xibs)) == 5, xibs
interface_classes = {
    node.attrib["customClass"]
    for path in xibs
    for node in ET.parse(path).iter()
    if "customClass" in node.attrib
}
assert interface_classes == {
    "Views_First_xib",
    "Views_Second_xib",
    "Other_Third_xib",
    "Base_lproj_Main_storyboard",
    "fr_lproj_Main_storyboard",
}, interface_classes

result = "Core Data and Interface Builder resource inputs parsed successfully\n"
if "--write-results" in args:
    Path(args[args.index("--write-results") + 1]).write_text(result)
else:
    print(result, end="")
