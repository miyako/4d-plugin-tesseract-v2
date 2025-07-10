//%attributes = {"invisible":true}
//class info
$json:=Tesseract Get info

SET TEXT TO PASTEBOARD:C523($json)

$info:=JSON Parse:C1218($json; Is object:K8:27)

//instance info
C_OBJECT:C1216($option)
$option:=New object:C1471
$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12
$json:=JSON Stringify:C1217($option)
$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)
$available_count:=$option.languages.available.length
$loaded_count:=$option.languages.loaded.length  //eng