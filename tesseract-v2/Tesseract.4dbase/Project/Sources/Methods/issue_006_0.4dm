//%attributes = {"invisible":true}
var $img : 4D:C1709.File
$img:=Folder:C1567(fk desktop folder:K87:19).file("IMG_0667 2.jpeg")

$tessdata:=Get 4D folder:C485(Current resources folder:K5:16)+"tessdata"+Folder separator:K24:12

$timeout:=5000

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

//the ".pdf" extension is automatically added
$output:=Temporary folder:C486+Generate UUID:C1066
$option:={lang: "eng"; tessdata: $tessdata; input: $input; output: $output; timeout: $timeout}

$json:=JSON Stringify:C1217($option)
$result:=JSON Parse:C1218(Tesseract($jpg; $json); Is object:K8:27)
$option:=JSON Parse:C1218($json; Is object:K8:27)

If (Bool:C1537($option.exportPdf.success))
	OPEN URL:C673($option.output+".pdf")
End if 