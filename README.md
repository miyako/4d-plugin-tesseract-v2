# 4d-plugin-tesseract-v2

OCR by [Tesseract 4.x](https://github.com/tesseract-ocr/tesseract)

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
||<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|

## Syntax

```
info:=Tesseract Get info 
```

Parameter|Type|Description
------------|------------|----
info|TEXT|``JSON``

* Mac: 

``info.version``: 4.1.0-rc1  
``info.leptonica``: leptonica-1.78.0  
``info.libraries``: libgif 5.1.4 : libjpeg 6b (libjpeg-turbo 2.0.0) : libpng 1.6.35 : libtiff 4.0.9 : zlib 1.2.11 : libwebp 1.0.0    
``info.SIM.isAVX512BWAvailable``: false  
``info.SIM.isAVX512FAvailable``: false  
``info.SIM.isAVX2Available``: true  
``info.SIM.isAVXAvailable``: true  
``info.SIM.isSSEAvailable``: true  

c.f. 

[SIMD](https://en.wikipedia.org/wiki/SIMD)  
[SSE](https://en.wikipedia.org/wiki/Streaming_SIMD_Extensions)  
[AVX](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions)  

**Note**: Jpeg2000 (.jp2) support is disabled (probably not thread-safe)

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

**Note**: By default all pages are processed for TIFF

See also 

#### [Standard Options](standard-options.md)
