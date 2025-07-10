//%attributes = {}
//hindi-to-english.jpeg

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