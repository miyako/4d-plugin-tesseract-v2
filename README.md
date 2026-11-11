![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-tesseract-v2)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-tesseract-v2/total)

**Note**: for v17 and earlier, move `manifest.json` to `Contents`

# 4d-plugin-tesseract-v2

OCR by [Tesseract 4.x](https://github.com/tesseract-ocr/tesseract). The plugin links Tesseract 4.1.1 and [Leptonica](http://www.leptonica.org) statically, decodes an image you pass as a `BLOB` (or read from a file path), runs Tesseract on it, and returns the recognised text as JSON `Text`. It can also write a searchable PDF, return word, line or block bounding boxes, and run orientation and script detection. Language models (`.traineddata` files) are **not** bundled with the plugin: you point it at a `tessdata` folder.

| Command | Returns | Purpose |
|---|---|---|
| [Tesseract Get info](#tesseract-get-info) | `Text` (JSON) | Versions of Tesseract, Leptonica and the image libraries, and the CPU SIMD features Tesseract detected |
| [Tesseract](#tesseract) | `Text` (JSON) | Recognise the text in an image, export a searchable PDF, or list the available languages |

**Platforms:** macOS 11.5 or later (universal: Apple silicon and Intel), Windows 64-bit.

---

## Requirements & platform notes

- **You must supply a `tessdata` folder** and pass its path in the `tessdata` option. The test database ships one in `Tesseract.4dbase/Resources/tessdata`: the 4.0.0 [tesseract-ocr/tessdata](https://github.com/tesseract-ocr/tessdata) set (about 1 GB) plus `pdf.ttf`. A language is usable only if its `<lang>.traineddata` is in that folder; `osd` needs `osd.traineddata`; PDF export needs `pdf.ttf`.
- **Paths are system paths**: on macOS an HFS path (`Macintosh HD:Users:...`, what `Get 4D folder` and `Folder separator` produce), on Windows a normal Windows path. On macOS the plugin converts `tessdata`, `input` and `output` to POSIX paths and adds a trailing `/` to `tessdata`. On Windows they are passed unchanged, so end `tessdata` with a separator, as all the examples do.
- **Failure is silent, not a 4D error.** Neither command raises a 4D error. A wrong `tessdata` path or a missing language returns `{"results":[]}` and leaves the options text unchanged; check for the `languages` property (see [Tesseract](#tesseract)).
- **Both parameters of `Tesseract` are mandatory**, even when you read the image from a file with `input`: pass an empty `BLOB` in that case.
- Both commands are declared thread-safe in the manifest, so they can be called from preemptive processes.
- During recognition the plugin yields to 4D every 150 characters (Tesseract is patched for this), so a cooperative process doesn't block the application while a large page is read.
- **On Windows**, Leptonica and Tesseract are patched to accept Unicode file paths, and JPEG 2000 (`.jp2`) decoding is disabled. Leptonica is 1.78.0 on Windows and 1.80.0 on macOS, with different image library versions (see [Tesseract Get info](#tesseract-get-info)).

---

## Tesseract Get info

### Syntax

```
info:=Tesseract Get info
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | JSON object, see below |

### Description

Returns a JSON object (as text) describing the libraries the plugin was built with. It needs no `tessdata`.

| Property | Type | Description |
|---|---|---|
| `version` | Text | Tesseract version, e.g. `4.1.1` |
| `leptonica` | Text | Leptonica version, e.g. `leptonica-1.80.0` |
| `libraries` | Text | Image library versions, separated by ` : ` |
| `SIM` | Object | Booleans `isAVX512BWAvailable`, `isAVX512FAvailable`, `isAVX2Available`, `isAVXAvailable`, `isSSEAvailable`: the [SIMD](https://en.wikipedia.org/wiki/SIMD) instruction sets ([SSE](https://en.wikipedia.org/wiki/Streaming_SIMD_Extensions), [AVX](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions)) Tesseract detected on this CPU and uses to speed up recognition. These are x86 features; on Apple silicon (native arm64) expect `false` for all of them (inferred from Tesseract's detection code, not measured). |

Values reported by the 2.x builds:

- **macOS**: `leptonica-1.80.0`; `libgif 5.2.1 : libjpeg 9d : libpng 1.6.37 : libtiff 4.1.0 : zlib 1.2.11 : libwebp 1.1.0 : libopenjp2 2.3.1`
- **Windows**: `leptonica-1.78.0`; `libgif 5.1.4 : libjpeg 6b (libjpeg-turbo 1.5.3) : libpng 1.6.34 : libtiff 4.0.9 : zlib 1.2.11 : libwebp 1.0.0`

### Example

From the plugin's own test method (`Method1.4dm`):

```4d
//class info
$json:=Tesseract Get info

SET TEXT TO PASTEBOARD:C523($json)

$info:=JSON Parse:C1218($json; Is object:K8:27)
```

---

## Tesseract

### Syntax

```
result:=Tesseract(image; options)
```

| Parameter | Type | Description |
|---|---|---|
| `image` | BLOB | The image file's bytes: GIF, TIFF, PNG, BMP, WebP, PNM, JPEG (and JPEG 2000 on macOS). Ignored when `options` has `input`, but must still be passed. |
| `options` | Text | JSON object of options (see below). **Rewritten on return** when Tesseract initialises: the same object plus `languages`, and `exportPdf` for PDF export. Pass a variable. |
| Result | Text | JSON object `{"results":[...]}`, see below |

### Description

`Tesseract` creates a Tesseract engine for the call, initialises it with `tessdata`, `lang` and `oem`, applies any extra Tesseract variables, decodes the image, recognises it, and returns the results.

#### Options

| Property | Type | Description |
|---|---|---|
| `tessdata` | Text | Path of the `tessdata` folder (system path). Without it Tesseract falls back to its own default location, which normally doesn't exist on a 4D machine. |
| `lang` | Text | Language(s), e.g. `"eng"`, `"eng+jpn"`. Default `"eng"`. Each must have a `.traineddata` file in `tessdata`. |
| `oem` | Number | OCR engine mode: `0` legacy engine, `1` LSTM neural network, `2` both, `3` default (whatever the traineddata supports). Values above `3` fall back to `3`. |
| `format` | Text | Image format as a file extension: `.gif`, `.tif`/`.tiff`, `.png`, `.bmp`, `.webp`, `.pnm`, `.jpg`/`.jpeg` (case-insensitive). Without it the format is detected from the data. Needed to read every page of a TIFF. |
| `page` | Number | TIFF only: the page to read (0-based index, as Leptonica numbers pages). Without it, all pages are read. |
| `input` | Text | Read the image from this file instead of `image`. |
| `output` | Text | With `input`: write a searchable PDF to this path. Tesseract adds the `.pdf` extension. `pdf.ttf` must be in `tessdata`. |
| `timeout` | Number | PDF export only: Tesseract stops if any single page takes longer than this many milliseconds. Default `5000`. |
| `osd` | Boolean | Orientation and script detection instead of text. Needs `osd.traineddata`. |
| `getComponentImages` | Boolean | Split the page into text lines (or the level chosen with one of the `get…` options below) and recognise each region separately. |
| `getBlock`, `getParagraph`, `getTextLine`, `getWord`, `getSymbol` | Boolean | Return one result per block, paragraph, line, word or symbol, with its bounding box. |
| `clearGlobalCache` | Boolean | Clear Tesseract's process-wide cache of loaded language data before initialising. |
| any other property | | Passed to Tesseract as a variable (`SetVariable`) after initialisation, with the value converted to text. See [Standard Options](standard-options.md) for the names. |

Precedence, read from the code:

- `input` with `output` → PDF export; no text is returned and `results` stays empty.
- `osd` wins over `getComponentImages`, which wins over the `get…` bounding-box options.
- **The `get…` bounding-box options are selected by their presence, not their value**: `"getWord": false` still switches to word results. If several are present, the one that comes last alphabetically wins (`getWord`, then `getTextLine`, `getSymbol`, `getParagraph`, `getBlock`), because the options are read in key order. Pass only the one you want.

#### Result

`results` holds one element per page: one for a single image, one per page for a multi-page TIFF read without `page`. Each element's shape depends on the mode:

| Mode | Element |
|---|---|
| default | Object `{text; confidence}`: the page's text (lines separated by line feeds) and the mean confidence (0 to 100). |
| `get…` (bounding boxes) | Collection of `{text; confidence; left; top; right; bottom}`, one per block, paragraph, line, word or symbol. Coordinates are pixels from the top-left corner. |
| `getComponentImages` | Collection of `{x; y; width; height; text; confidence}`, one per region (text lines unless a `get…` option sets another level). |
| `osd` | Object `{orientation; direction; order; deskew}`: `orientation` 0 up, 1 right, 2 down, 3 left; `direction` (writing direction) and `order` (text line order) 0 left-to-right, 1 right-to-left, 2 top-to-bottom; `deskew` is the remaining skew in radians, between -π/4 and π/4. |

`results` is empty when Tesseract couldn't initialise, when the image couldn't be decoded, and in PDF export mode.

#### Options returned

When initialisation succeeds, `options` is replaced by the JSON of the object you passed, plus:

| Property | Type | Description |
|---|---|---|
| `languages.available` | Collection | Languages found in `tessdata` |
| `languages.loaded` | Collection | Languages loaded for this call |
| `exportPdf.success` | Boolean | PDF export only: whether the PDF was written |

The returned JSON is indented over several lines; parse it with `JSON Parse`.

### Example

List the languages with an "empty" call: an empty `BLOB` and only `tessdata`. From the plugin's own test method (`Method1.4dm`):

```4d
//instance info
C_OBJECT:C1216($option)
$option:=New object:C1471
$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12
$json:=JSON Stringify:C1217($option)
$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)
$available_count:=$option.languages.available.length
$loaded_count:=$option.languages.loaded.length  //eng
```

Recognise an image passed as a `BLOB`. From `Method2.4dm` (the author's comments note stray characters and truncated Hindi with `oem` 3 on this sample):

```4d
$path:=Get 4D folder:C485(Current resources folder:K5:16)+"images"+Folder separator:K24:12+"hindi-to-english.jpeg"
C_BLOB:C604($data)
DOCUMENT TO BLOB:C525($path; $data)


C_OBJECT:C1216($option)
$option:=New object:C1471
$option.lang:="eng+hin"
$option.oem:=3

$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12

$json:=JSON Stringify:C1217($option)

// FAIL

$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)

//strange "N" at the bottom with oem:3; also Hindi text is truncated

ALERT:C41($result.results[0].text)
```

A picture converted to JPEG, with the text of all results joined. From `issue_006_1.4dm`:

```4d
var $img : 4D:C1709.File
$img:=Folder:C1567(fk desktop folder:K87:19).file("IMG_0667.jpeg")

$tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12

$timeout:=5000
READ PICTURE FILE:C678($img.platformPath; $image)
PICTURE TO BLOB:C692($image; $jpg; ".jpg")

$option:={lang: "eng"; tessdata: $tessdata; timeout: $timeout}

$json:=JSON Stringify:C1217($option)
$result:=JSON Parse:C1218(Tesseract($jpg; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)

SET TEXT TO PASTEBOARD:C523($result.results.extract("text").join("\r"))
```

Every page of a TIFF (`format` is required for that). From `Method8.4dm`:

```4d
$path:=System folder:C487(Desktop:K41:16)+"test.tif"

C_BLOB:C604($data)
DOCUMENT TO BLOB:C525($path; $data)

C_OBJECT:C1216($option)
$option:=New object:C1471
$option.lang:="eng"
//$option.oem:=2
$option.format:=".tif"  //.tiff is acceptable too

$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12

$json:=JSON Stringify:C1217($option)

$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)
```

Searchable PDF from an image file. From `issue_006_2.4dm`:

```4d
var $img : 4D:C1709.File
$img:=Folder:C1567(fk desktop folder:K87:19).file("IMG_0667.jpeg")

$tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12

$timeout:=5000
READ PICTURE FILE:C678($img.platformPath; $image)
PICTURE TO BLOB:C692($image; $jpg; ".jpg")

//input must be file
$input:=Temporary folder:C486+Generate UUID:C1066+".jpg"
BLOB TO DOCUMENT:C526($input; $jpg)
CLEAR VARIABLE:C89($jpg)

//the ".pdf" extension is automatically added
$output:=Temporary folder:C486+Generate UUID:C1066
$option:={lang: "eng"; tessdata: $tessdata; input: $input; output: $output; timeout: $timeout}

$json:=JSON Stringify:C1217($option)
$result:=JSON Parse:C1218(Tesseract($jpg; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)

If (Bool:C1537($option.exportPdf.success))
	OPEN URL:C673($option.output+".pdf")
End if 
```

For large photos, `issue_006_0.4dm` scales the picture down before writing the temporary input file:

```4d
//scaling
READ PICTURE FILE:C678($img.platformPath; $image)
PICTURE PROPERTIES:C457($image; $width; $height)
$max:=1000
$side:=$width>$height ? $width : $height
$scale:=$max/$side
TRANSFORM PICTURE:C988($image; Scale:K61:2; $scale; $scale)
//input must be file
$input:=Temporary folder:C486+Generate UUID:C1066+".jpg"
WRITE PICTURE FILE:C680($input; $image)
```

Component images and orientation detection: `Method5.4dm` and `Method6.4dm` are `Method4.4dm` (an `input` path with `lang` and `tessdata`) plus one option each:

```4d
$option.getComponentImages:=True:C214
```

```4d
$option.osd:=True:C214  //orientation and script detection
```

Word bounding boxes (illustrative):

```4d
var $option; $result; $word : Object
var $json : Text
var $data : Blob

$option:=New object("lang"; "eng"; "getWord"; True)
$option.tessdata:=Get 4D folder(Current resources folder)+"tessdata"+Folder separator
$option.input:=Get 4D folder(Current resources folder)+"images"+Folder separator+"jpn-eng.png"
$json:=JSON Stringify($option)

$result:=JSON Parse(Tesseract($data; $json); Is object)

If ($result.results.length#0)
	For each ($word; $result.results[0])
		// $word.text, $word.confidence, $word.left, $word.top, $word.right, $word.bottom
	End for each 
End if 
```

---

## Error handling & troubleshooting

- **`results` is empty and `options` has no `languages`**: Tesseract couldn't initialise. Check that `tessdata` points at the folder (with a trailing separator) and that every language in `lang` has a `.traineddata` file there.
- **`results` is empty but `languages` is present**: the image wasn't decoded. Check `format` (it must match the data; leave it out to auto-detect), the `input` path, and on Windows that the image isn't JPEG 2000.
- **A multi-page TIFF returns one page**: pass `"format": ".tif"`. Without it only the first page is decoded; with `page`, only that page.
- **An option of the wrong type** (for example `"page": "1"`, a negative `oem`, or an object where text is expected, such as a `4D.File` instead of a path in `input`) stops the call, which then returns `{"results":[]}`. This is the behaviour after the 2026 review fixes; earlier builds could leave the 4D process waiting for a result that never came.
- **Unexpected bounding-box level**: the `get…` options are selected by presence, not value, and the alphabetically last one wins. Remove the ones you don't want instead of setting them to `false`.
- **PDF not written**: `output` needs `input`, `pdf.ttf` must be in `tessdata`, and the target folder must exist. Read `exportPdf.success` from the returned options; the file name gets `.pdf` appended.
- **Poor accuracy or stray characters**: try another `oem`, restrict `lang` to the languages actually on the page, or scale large photos down first (`issue_006_0.4dm`).
- **`clearGlobalCache` with concurrent calls**: the cache is shared by every process, and the plugin doesn't guard against clearing it while another process is recognising text. Use it only when no other OCR call is running.
- **libtiff warnings** go to the process's standard error, not to 4D.

---

## Quick reference

```4d
// languages in a tessdata folder
$option:=New object("tessdata"; Get 4D folder(Current resources folder)+"tessdata"+Folder separator)
$json:=JSON Stringify($option)
$result:=Tesseract($data; $json)
$option:=JSON Parse($json; Is object)
$languages:=$option.languages.available

// text of an image BLOB
$option:=New object("tessdata"; $tessdata; "lang"; "eng+jpn")
$json:=JSON Stringify($option)
$result:=JSON Parse(Tesseract($blob; $json); Is object)
$text:=$result.results.extract("text").join("\r")

// searchable PDF
$option:=New object("tessdata"; $tessdata; "lang"; "eng"; "input"; $imagePath; "output"; $pdfPathWithoutExtension)
$json:=JSON Stringify($option)
$result:=Tesseract($blob; $json)
$option:=JSON Parse($json; Is object)
$ok:=Bool($option.exportPdf.success)
```

See also

#### [Standard Options](standard-options.md)
