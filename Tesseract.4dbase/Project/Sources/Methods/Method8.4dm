//%attributes = {"invisible":true}
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