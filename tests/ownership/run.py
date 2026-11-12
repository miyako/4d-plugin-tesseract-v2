#!/usr/bin/env python3
"""Compile all native build members; execute only synthetic memory boundaries."""
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

arguments = [arg for arg in sys.argv[1:] if arg != "--expect-baseline"]
baseline = "--expect-baseline" in sys.argv
root = Path(arguments[0] if arguments else ".").resolve()
here = Path(__file__).resolve().parent
sources = [root / "4D Plugin API/4DPluginAPI.c",
           *sorted((root / "4D Plugin API/Classes").glob("*.cpp")), root / "4DPlugin.cpp"]
expected_members = {p.name for p in sources}
project = root / "Tesseract.xcodeproj/project.pbxproj"
objects = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", str(project)]))["objects"]
mac_members = set()
for obj in objects.values():
    if obj.get("isa") == "PBXSourcesBuildPhase":
        for key in obj["files"]:
            mac_members.add(Path(objects[objects[key]["fileRef"]]["path"]).name)
if mac_members != expected_members:
    raise RuntimeError("Xcode source membership changed: " + repr(mac_members))
for name in ("Tesseract.vcxproj", "Tesseract.vc10.vcxproj"):
    members = {entry.attrib["Include"].replace("\\", "/").split("/")[-1]
               for entry in ET.parse(root / name).iter()
               if entry.tag.endswith("}ClCompile") and "Include" in entry.attrib}
    if members != expected_members:
        raise RuntimeError("Windows source membership changed: " + name)
print("PASS all 18 native build members inventoried on both platforms", flush=True)
inputs = set(sources + list((root / "4D Plugin API").rglob("*.h")) +
             [root / "4DPlugin.h", root / "manifest.json", root / "4D Plugin_Prefix.pch",
              project, root / "Tesseract.vcxproj", root / "Tesseract.vc10.vcxproj",
              here / "main.mm", here / "run.py"] +
             list((here / "boundaries").glob("*.h")) +
             list((root / "include/leptonica").glob("*.h")) +
             list((root / "include/tiff").glob("*.h")))
for path in sorted(inputs):
    print(hashlib.sha256(path.read_bytes()).hexdigest(), path, flush=True)

with tempfile.TemporaryDirectory(prefix="tesseract-v2-ownership-") as directory:
    out = Path(directory)
    flags = ["-g", "-O1", "-fsanitize=address,undefined", "-fno-sanitize=alignment",
             "-fno-omit-frame-pointer", "-Wno-deprecated-declarations", "-Wno-multichar",
             "-Wno-deprecated-builtins", "-Dfopen=ownership_fopen", "-Dfclose=ownership_fclose",
             "-include", str(root / "4D Plugin_Prefix.pch")]
    for path in [here / "boundaries", root / "4D Plugin API", root / "4D Plugin API/Classes",
                 root, root / "include/leptonica", root / "include/tiff"]:
        flags.append("-I" + str(path))
    objects = []
    for i, source in enumerate(sources + [here / "main.mm"]):
        obj = out / (str(i) + ".o")
        subprocess.run(["clang++", *flags, "-x", "objective-c++", "-std=c++14",
                        "-c", str(source), "-o", str(obj)], check=True)
        objects.append(str(obj))
    exe = out / "ownership"
    subprocess.run(["clang++", *flags, *objects, "-framework", "Cocoa",
                    "-framework", "CoreFoundation", "-o", str(exe)], check=True)
    imports = subprocess.check_output(["nm", "-u", str(exe)], text=True)
    exact = {
        "_abort", "_calloc", "_free", "_malloc", "_realloc", "_memcmp", "_memcpy",
        "_memmove", "_memset", "_strlen", "_strdup", "_wcslen", "_isspace", "_sprintf",
        "_snprintf", "_vsnprintf", "_printf", "_fprintf", "_vfprintf", "_fwrite", "_puts", "___stderrp",
        "_exit", "_atexit", "_bzero", "dyld_stub_binder", "__Unwind_Resume", "_memchr",
        "_kCFAllocatorDefault", "_CFRelease", "_CFStringCreateWithBytes",
        "_CFStringCreateWithCharacters", "_CFStringGetLength", "_CFStringGetCharacters",
        "_CFStringGetMaximumSizeForEncoding", "_CFStringGetBytes", "__DefaultRuneLocale",
        "_class_getClassMethod", "_class_getInstanceMethod", "_method_setImplementation",
        "_sel_registerName", "___stack_chk_fail", "___stack_chk_guard",
        "_NSZeroSize", "___CFConstantStringClassReference", "___gxx_personality_v0",
        "___maskrune", "___sanitizer_annotate_contiguous_container",
    }
    classes = {"NSString", "NSMutableString", "NSURL", "NSData", "NSImage"}
    unexpected = []
    for symbol in (s.strip() for s in imports.splitlines() if s.strip()):
        if any(s in symbol for s in ("basic_filebuf", "basic_ifstream", "basic_ofstream",
                                     "basic_fstream", "filesystem", "random_device")):
            raise RuntimeError("Forbidden external-data import: " + symbol)
        if symbol.startswith("_OBJC_CLASS_$_") and symbol[14:] in classes:
            continue
        if symbol in exact or symbol.startswith(("___asan", "___ubsan", "___cxa", "__Z", "_objc_")):
            continue
        unexpected.append(symbol)
    if unexpected:
        raise RuntimeError("Unexpected imports before execution: " + repr(unexpected))
    metadata = subprocess.check_output(
        ["otool", "-v", "-s", "__TEXT", "__objc_methname", str(exe)], text=True)
    selectors = set(re.findall(r"^[0-9a-f]+\s+(\S+)\s*$", metadata, re.MULTILINE))
    allowed_selectors = {
        "alloc", "release", "class", "length", "UTF8String", "bytes", "absoluteString",
        "TIFFRepresentation", "stringWithUTF8String:", "initWithUTF8String:",
        "initWithCharacters:length:", "initWithString:", "getCString:maxLength:encoding:",
        "initWithCGImage:size:", "getCharacters:range:", "getFileSystemRepresentation:maxLength:",
        "initFileURLWithPath:", "initWithContentsOfFile:",
    }
    if not selectors or selectors - allowed_selectors:
        raise RuntimeError("Unexpected Objective-C selector metadata: " + repr(sorted(selectors)))
    print("PASS Objective-C selector gate " + repr(sorted(selectors)), flush=True)
    linked = subprocess.check_output(["otool", "-L", str(exe)], text=True)
    libraries = "\n".join(linked.splitlines()[1:]).lower()
    if any(n in libraries for n in ("tesseract", "leptonica", "libjpeg", "libpng", "libtiff")):
        raise RuntimeError("Real OCR/codec linked")
    print("PASS pre-execution synthetic boundary/import gate", flush=True)
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0", UBSAN_OPTIONS="halt_on_error=1")
    results, outputs = [], []
    cases = [[]] + [[mode, name] for mode in ("resize", "null") for name in (
        "ARRAY_TEXT", "ARRAY_BOOLEAN", "ARRAY_INTEGER", "ARRAY_LONGINT", "ARRAY_REAL",
        "ARRAY_DATE", "ARRAY_TIME")] + [["--picture-copy"], ["--picture-allocation"]]
    for args in cases:
        print("CASE", args or ["all-consumers"], flush=True)
        result = subprocess.run([str(exe), *args], env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        print(result.stdout, end="", flush=True)
        results.append(result.returncode); outputs.append(result.stdout)
    print("case_exit_codes=" + repr(results), flush=True)
    if baseline:
        failed = "\n".join(line for line in outputs[0].splitlines() if line.startswith("FAIL ")) + "\n"
        print("baseline_failure_sha256=" + hashlib.sha256(failed.encode()).hexdigest())
        if results != [1] + [-6] * 16 or "checks=234 failures=57" not in outputs[0]:
            raise RuntimeError("Unexpected baseline process status")
        if hashlib.sha256(failed.encode()).hexdigest() != "97453c0781ca727c1b36c34f92c7a715abfaf28607e96a29a5b82a4270923659":
            raise RuntimeError("Unexpected baseline failure signature")
        for output in outputs[1:8] + outputs[15:16]:
            if "AddressSanitizer: heap-buffer-overflow" not in output:
                raise RuntimeError("Missing expected isolated baseline ASan overflow")
        for output in outputs[8:15]:
            if "runtime error: load of null pointer" not in output:
                raise RuntimeError("Missing expected isolated baseline UBSan null input")
        # Failed PA_NewHandle is ignored and the null handle reaches PA_LockHandle.
        if outputs[16].strip() != "SYNTHETIC-DEFECT unowned handle use op=5 null=1":
            raise RuntimeError("Missing expected isolated baseline null picture handle use")
        print("PASS exact immutable-baseline failure signature and isolated sanitizer cases", flush=True)
        sys.exit(0)
    sys.exit(1 if any(results) else 0)
