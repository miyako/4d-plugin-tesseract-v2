//%attributes = {"invisible":true}
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