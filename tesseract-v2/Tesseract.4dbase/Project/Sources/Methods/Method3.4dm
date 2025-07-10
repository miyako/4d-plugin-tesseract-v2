//%attributes = {"invisible":true}
$path:=Get 4D folder:C485(Current resources folder:K5:16)+"images"+Folder separator:K24:12+"jpn-eng.png"


$path:=Folder:C1567(fk desktop folder:K87:19).file("1.jpg")

C_OBJECT:C1216($option)
$option:=New object:C1471
$option.lang:="eng+jpn"
$option.input:=$path
$option.output:=System folder:C487(Desktop:K41:16)+"test"  //the ".pdf" extension is automatically added
$option.timeout:=10000  //ms

$option.tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12
//the file "pdf.ttf" must be present here

$json:=JSON Stringify:C1217($option)

$result:=JSON Parse:C1218(Tesseract($data; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)

If (Bool:C1537($option.exportPdf.success))
	OPEN URL:C673($option.output+".pdf")
End if 