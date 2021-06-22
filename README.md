![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-tesseract-v2)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-tesseract-v2/total)

**Note**: for v17 and earlier, move `manifest.json` to `Contents`

# 4d-plugin-tesseract-v2

OCR by [Tesseract 4.x](https://github.com/tesseract-ocr/tesseract)

## Syntax

```
info:=Tesseract Get info 
```

Parameter|Type|Description
------------|------------|----
info|TEXT|``JSON``

* Mac: 

``info.version``: 4.1.1  
``info.leptonica``: leptonica-1.80.0  
``info.libraries``: libgif 5.2.1 : libjpeg 9d : libpng 1.6.37 : libtiff 4.1.0 : zlib 1.2.11 : libwebp 1.1.0 : libopenjp2 2.3.1   
``info.SIM.isAVX512BWAvailable``: false  
``info.SIM.isAVX512FAvailable``: false  
``info.SIM.isAVX2Available``: true  
``info.SIM.isAVXAvailable``: true  
``info.SIM.isSSEAvailable``: true 

* Windows: 

``info.version``: 4.1.1 
``info.leptonica``: leptonica-1.78.0  
``info.libraries``: libgif 5.1.4 : libjpeg 6b (libjpeg-turbo 1.5.3) : libpng 1.6.34 : libtiff 4.0.9 : zlib 1.2.11 : libwebp 1.0.0    
``info.SIM.isAVX512BWAvailable``: false  
``info.SIM.isAVX512FAvailable``: false  
``info.SIM.isAVX2Available``: true  
``info.SIM.isAVXAvailable``: true  
``info.SIM.isSSEAvailable``: true 

c.f. 

[SIMD](https://en.wikipedia.org/wiki/SIMD)  
[SSE](https://en.wikipedia.org/wiki/Streaming_SIMD_Extensions)  
[AVX](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions)  

**Note**: Jpeg2000 (.jp2) support is disabled on windows (probably not thread-safe)

* leptonica and tesseract are patched to support unicode paths on Windows  
* tesseract is patched to "yield absolute" during OCR  

Make an "empty" call to obtain list of languages

```
C_OBJECT($option)
$option:=New object
$option.tessdata:=Get 4D folder(Current resources folder)+"tessdata"+Folder separator
$json:=JSON Stringify($option)
$result:=JSON Parse(Tesseract ($data;$json);Is object)
$option:=JSON Parse($json;Is object)
$available_count:=$option.languages.available.length
$loaded_count:=$option.languages.loaded.length  //eng
```

```
result:=Tesseract (image;options)
```

Parameter|Type|Description
------------|------------|----
image|BLOB|
options|TEXT|``JSON`` (output contains list of languages)
result|TEXT|``JSON``

A ``languages``property is added to ``options`` on return.

``languages.loaded[]``:  ``GetAvailableLanguagesAsVector()``  
``languages.available[]``: ``GetLoadedLanguagesAsVector()``  

### Examples

```
$path:=Get 4D folder(Current resources folder)+"images"+Folder separator+"hindi-to-english.jpeg"
C_BLOB($data)
DOCUMENT TO BLOB($path;$data)

C_OBJECT($option)
$option:=New object
$option.lang:="eng+hin"
$option.oem:=1
$option.tessdata:=Get 4D folder(Current resources folder)+"tessdata"+Folder separator

$json:=JSON Stringify($option)

$result:=JSON Parse(Tesseract ($data;$json);Is object)
$option:=JSON Parse($json;Is object)

ALERT($result.results[0].text)
```

#### Custom Options 

* ``clearGlobalCache``: boolean call ``ClearPersistentCache()`` before ``Init()``  
* ``oem``: number set ``OcrEngineMode``   
* ``lang``: string set language  
* ``format``: string specify image format by file extension   
* ``tessdata``: string specify ``TESSDATA_PREFIX`` by system path representation   
* ``page``: number specify page number for TIFF  
* ``getSymbol``: get bounds by symbols  
* ``getWord``: get bounds by words  
* ``getTextLine``: get bounds by lines  
* ``getParagraph``: get bounds by paragraphs  
* ``getBlock``: get bounds by blocks    
* ``getComponentImages``: get component images      
* ``osd``: orientation and script detection  

**Note**: By default all pages are processed for TIFF  

``osd`` and ``getComponentImages`` are mutually exclusive.  

``getSymbol``, ``getWord``, ``getTextLine``, ``getParagraph`` and ``getBlock`` are mutually exclusive.  

* ``input``: string use path instead of BLOB  
* ``output``: string create seachable PDF ``input`` must be specified as well  

**Note**: A searchable PDF is an image with invisible text over their approximate position.

```
$path:=Get 4D folder(Current resources folder)+"images"+Folder separator+"jpn-eng.png"

C_OBJECT($option)
$option:=New object
$option.lang:="eng+jpn"
$option.input:=$path
$option.output:=System folder(Desktop)+"test"  //the ".pdf" extension is automatically added

$option.tessdata:=Get 4D folder(Current resources folder)+"tessdata"+Folder separator
  //the file "pdf.ttf" must be present here

$json:=JSON Stringify($option)

$result:=JSON Parse(Tesseract ($data;$json);Is object)
$option:=JSON Parse($json;Is object)

If (Bool($option.exportPdf.success))
	OPEN URL($option.output+".pdf")
End if 
```

See also 

#### [Standard Options](standard-options.md)
