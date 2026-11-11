//%attributes = {"invisible":true}
$path:=Get 4D folder:C485(Current resources folder:K5:16)+"images"+Folder separator:K24:12+"jpn-eng.png"

C_OBJECT:C1216($option)
$option:=New object:C1471
$option.lang:="eng+jpn"
$option.input:=$path

$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12
$option.getComponentImages:=True:C214

$json:=JSON Stringify:C1217($option)

$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)
