# Synthetic ownership regression

`python3 tests/ownership/run.py` compiles every native build member (`4DPluginAPI.c`, the 17 `4D Plugin API/Classes/*.cpp` and `4DPlugin.cpp`) with AddressSanitizer and UndefinedBehaviorSanitizer. It links them against a synthetic in-memory 4D engine and synthetic Tesseract/Leptonica/TIFF boundaries (`boundaries/`). The bundled SDK (`4DPluginAPI.c/.h/.def`, `EntryPoints.h`, `Flags.h`, `PrivateTypes.h`, `PublicTypes.h`) is compiled unchanged.

## Safety gates

Before anything executes, the runner checks:

- build membership, which must be identical in the Xcode project and both vcxproj files;
- the manifest signatures;
- the undefined imports and the Objective-C selector metadata;
- that no real OCR or codec library is linked.

It never reads images, files, devices, the network or the UI. File and URL selectors are replaced with stubs that abort.

## Cases

| Case | Covers |
|---|---|
| all-consumers | Both exported selectors through the actual dispatcher. Also C_TEXT/C_BLOB/C_PICTURE/C_POINTER and all `ARRAY_*` wrappers with ASCII, BMP, supplementary and empty text, plus owner balances and injected engine errors. |
| `resize <ARRAY_*>` (×7) | Output array whose `PA_ResizeArray` fails |
| `null <ARRAY_*>` (×7) | Array input whose data handle is null |
| `--picture-copy` | Byte count from `PA_ConvertCharsetToCharset` used as UTF-16 units |
| `--picture-allocation` | Failed `PA_NewHandle` in `CPicture::loadImageOfType` |

`--expect-baseline <tree>` runs the same harness against an unmodified tree. The pinned baseline result for d74b8d34ff9f142ec786154f7c256a8ff5fed72a is:

- **all-consumers:** exit 1, 234 checks with 57 named failures. The FAIL-line sha256 is `97453c0781ca727c1b36c34f92c7a715abfaf28607e96a29a5b82a4270923659`.
- **resize cases:** ASan heap-buffer-overflow inside `PA_Set*InArray`, because the SDK keeps the new element count after a failed allocation.
- **null cases:** UBSan null load.
- **`--picture-copy`:** ASan overflow.
- **`--picture-allocation`:** `PA_LockHandle(NULL)`.

The fixed tree passes every case with exit 0.

## Not covered

The harness does not cover:

- Windows or a real 4D host;
- real out-of-memory conditions or packed-struct alignment (UBSan alignment is disabled);
- leak detection (LSan is off; owner balances are checked explicitly instead);
- real Tesseract, Leptonica or image codecs.

Who owns the format descriptor returned by `PA_GetPictureData` is not specified by the bundled SDK, so the harness does not test it.
