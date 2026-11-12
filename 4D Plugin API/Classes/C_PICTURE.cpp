/*
 *  C_PICTURE.cpp
 *  4D Plugin
 *
 *  Created by miyako on 11/01/03.
 *
 */

#include "C_PICTURE.h"
#include <stdexcept>
#include <string>

namespace {
class PictureArguments {
	PA_Variable values[4];
	short count;
public:
	explicit PictureArguments(short n) : count(n) {
		for (short i = 0; i < count; ++i)
			values[i] = PA_CreateVariable(eVK_Undefined);
	}
	~PictureArguments() {
		for (short i = 0; i < count; ++i) PA_ClearVariable(&values[i]);
	}
	PA_Variable& operator[](size_t i) { return values[i]; }
	void execute(PA_long32 command) {
		PA_Variable result = PA_ExecuteCommandByID(command, values, count);
		const PA_ErrorCode error = PA_GetLastError();
		if (error != eER_NoErr)
			throw std::runtime_error("4D picture command failed: " + std::to_string(error));
		PA_ClearVariable(&result);
	}
	PictureArguments(const PictureArguments&) = delete;
	PictureArguments& operator=(const PictureArguments&) = delete;
};
}

#define CMU_TRANSFORM_PICTURE 988
#define CMU_PICTURE_PROPERTIES 457
#define CMU_CREATE_THUMBNAIL 679
#define CMU_CONVERT_PICTURE 1002

unsigned int CPicture::_GetCount()
{
	uint32_t i;
	PA_ErrorCode err = eER_NoErr;
	PA_Unistring type;
	
	this->_Types.clear();
	
	i = 0;
	
	while (err == eER_NoErr) 
	{
		type = PA_GetPictureData(this->_CPicture, ++i, NULL);
		err = PA_GetLastError();
		
		if(err == eER_NoErr)
		{
			uint32_t len;
			
			len = (uint32_t)(type.fLength * 4) + sizeof(uint8_t);
			std::vector<uint8_t> buf(len);
			
			PA_ConvertCharsetToCharset(
									   (char *)type.fString, 
									   type.fLength * sizeof(PA_Unichar), 
									   eVTC_UTF_16, 
									   (char *)&buf[0],
									   len, 
									   eVTC_UTF_8
									   );			
			CUTF8String uti;
			uti = CUTF8String((const uint8_t *)&buf[0]);
			CUTF8String typestring;
			
			size_t pos, found; 
			found = 0;
			
			for(pos = uti.find(';'); pos != CUTF8String::npos; pos = uti.find(';', found))
			{
				typestring = uti.substr(found, pos-found);
				found = pos + 1;
				this->_Types.insert(std::map<CUTF8String, uint32_t>::value_type(typestring, i));				
			}
			
			typestring = uti.substr(found, uti.length()-found);
			this->_Types.insert(std::map<CUTF8String, uint32_t>::value_type(typestring, i));				
			
		}
	}
	
	return (i-1);
}

bool CPicture::loadImageOfType(CUTF8String *pType)
{
	bool result = false;
	
	if(pType->length())
	{	
		
		std::map<CUTF8String, uint32_t>::iterator itr;
		
		itr = this->_Types.find(pType->c_str());
		
		PA_ErrorCode err = eER_IncompatibleTypes;
		
		if (itr != this->_Types.end()) 
		{
			uint32_t pos = itr->second;
			
			if(this->_TypeNum == pos)
			{
				result = true;
			}else{
				
				PA_Handle h = PA_NewHandle(0);	
				const PA_ErrorCode allocationError = PA_GetLastError();
				if (allocationError != eER_NoErr)
					throw std::runtime_error("4D picture handle allocation failed: " + std::to_string(allocationError));
				
				err = eER_NoErr;
				PA_GetPictureData(this->_CPicture, pos, h);
				err = PA_GetLastError();
				
				if(err == eER_NoErr)
				{
					this->_CBytes->setBytes((const uint8_t *)PA_LockHandle(h), PA_GetHandleSize(h));
					PA_UnlockHandle(h);
					
					this->_Type = CUTF8String(pType->c_str());
					this->_TypeNum = pos;
					result = true;
				}
				PA_DisposeHandle(h);
			}	
			
		}
		
	}
	
	return result;
	
}

void CPicture::fromFileAtPath(CUTF8String *pFilePath)
{	
	C_TEXT filePath;
	filePath.setUTF8String(pFilePath);
	
	PA_Unistring _path = PA_CreateUnistring((PA_Unichar *)filePath.getUTF16StringPtr());
	
	PictureArguments args(2);
	PA_SetStringVariable(&args[0], &_path);
	args[1] = PA_CreateVariable(eVK_Picture);
	
	args.execute(678);
	
	PA_Picture p = PA_GetPictureVariable(args[1]);
	
	setPicture(p);
	
}

void CPicture::setBytes(const uint8_t *bytes, uint32_t len)
{
	PA_Picture p = PA_CreatePicture((void *)bytes, len);
	const PA_ErrorCode error = PA_GetLastError();
	if (error != eER_NoErr)
		throw std::runtime_error("4D picture creation failed: " + std::to_string(error));
	setPicture(p);	
	PA_DisposePicture(p);
}

const uint8_t *CPicture::getBytesPtr(CUTF8String *pType)
{
	if(this->loadImageOfType(pType))
	{
		return this->_CBytes->getBytesPtr();
	}else{
		return 0;
	}
}

uint32_t CPicture::getBytesLength(CUTF8String *pType)
{
	if(this->loadImageOfType(pType))
	{
		return this->_CBytes->getBytesLength();
	}else{
		return 0;
	}	
}

void CPicture::setPicture(PA_Picture picture)
{
	if(picture)
	{
		if(this->_CPicture != picture)
		{
			PA_DisposePicture(this->_CPicture);
			this->_CPicture = PA_DuplicatePicture(picture, 1);//1=retain
			this->_Count = _GetCount();
			this->_TypeNum = 0;
			this->_Type = CUTF8String();
			this->_CBytes->setBytes(NULL, 0);
		}
	}
}

void CPicture::fromParamAtIndex(PackagePtr pParams, uint32_t index)
{
	if(index)
	{
		PA_Picture p = *(PA_Picture *)(pParams[index - 1]);	
		setPicture(p);
	}
}

void CPicture::toParamAtIndex(PackagePtr pParams, uint32_t index)
{
	if(index)
	{
		PA_Picture *p = (PA_Picture *)(pParams[index - 1]);
		
		if (*p)
		{
			if(*p != this->_CPicture)
			{
				PA_DisposePicture(*p);
				*p = PA_DuplicatePicture(this->_CPicture, 1);//1=retain			
			}
		}else{
			
			//happens in compiled mode
			*p = PA_DuplicatePicture(this->_CPicture, 1);//1=retain	
			
		}
	}	
}

void CPicture::setReturn(sLONG_PTR *pResult)
{
	PA_Picture *p = (PA_Picture *)pResult;
	*p = PA_DuplicatePicture(this->_CPicture, 1);//1=retain	
}

PA_Picture CPicture::getPicture()
{
	return this->_CPicture;	
}

uint32_t CPicture::getCount()
{
	return this->_Count;		
}

PA_Picture CPicture::createCopy(const char* type)
{
    CUTF8String u8 = CUTF8String((const uint8_t *)type);
    
    uint32_t size = ((uint32_t)u8.length() * sizeof(PA_Unichar)) + sizeof(PA_Unichar);
    std::vector<uint8_t> buf(size);
    uint32_t len = PA_ConvertCharsetToCharset(
                                              (char *)u8.c_str(),
                                              (uint32_t)u8.length(),
                                              eVTC_UTF_8,
                                              (char *)&buf[0],
                                              size,
                                              eVTC_UTF_16
                                              );    
    const PA_ErrorCode error = PA_GetLastError();
    if (error != eER_NoErr || len > size || len % sizeof(PA_Unichar))
        throw std::runtime_error("4D picture type conversion failed: " + std::to_string(error));
    CUTF16String u16 = CUTF16String((const PA_Unichar *)&buf[0], len / sizeof(PA_Unichar));
    
    PA_Unistring u = PA_CreateUnistring((PA_Unichar*)u16.c_str());
    
    PA_Picture p;
    
    p = PA_DuplicatePicture(this->_CPicture, 1);
    
    PictureArguments args(2);
    PA_SetPictureVariable(&args[0], p);
    
    PA_SetStringVariable(&args[1], &u);
    args.execute(CMU_CONVERT_PICTURE);
    
    p = PA_GetPictureVariable(args[0]);
    
    PA_SetPictureVariable(&args[0], NULL);
    
    
    return p;    
}

PA_Picture CPicture::createGrayScale()
{
	PA_Picture p;
	
	p = PA_DuplicatePicture(this->_CPicture, 1);
	
	PictureArguments args(2);
	args[1] = PA_CreateVariable(eVK_Longint);
	
	PA_SetPictureVariable(&args[0], p);	
	PA_SetLongintVariable(&args[1], 101);
	
	args.execute(CMU_TRANSFORM_PICTURE);
	
	p = PA_GetPictureVariable(args[0]);

	PA_SetPictureVariable(&args[0], NULL);
	
	
	return p;	
}

#if VERSIONMAC
#ifdef __OBJC__	
NSImage* CPicture::copyImage()
{
    CGImageRef cgImage = NULL;
    NSImage *nsImage = NULL;
    
    cgImage = (CGImageRef)PA_CreateNativePictureForScreen(this->_CPicture);
    
    if(cgImage)
    {
        //  10.6
        nsImage = [[NSImage alloc]initWithCGImage:cgImage size:NSZeroSize];
        /*
        CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);	
        CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, kUTTypeTIFF, 1, NULL);
        CFMutableDictionaryRef properties = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
        
        CGImageDestinationAddImage(destination, cgImage, properties);
        CGImageDestinationFinalize(destination);
        
        CFRelease(destination);
        CFRelease(properties);
        
        nsImage = [[NSImage alloc]initWithData:(NSData *)data];
        
        CFRelease(data);
        */         
        CFRelease(cgImage);

    }
    return nsImage;    
}  

void CPicture::setImage(NSImage *image)
{
    if(image){
        NSData *imageData = [image TIFFRepresentation];
        this->setBytes((const uint8_t *)[imageData bytes], [imageData length]);
    }
}
#endif
#endif

void CPicture::getSize(unsigned int *width, unsigned int *height)
{
	PictureArguments args(3);
	args[1] = PA_CreateVariable(eVK_Longint);		
	args[2] = PA_CreateVariable(eVK_Longint);	
	
	PA_SetPictureVariable(&args[0], PA_DuplicatePicture(this->_CPicture, 1));
	
	args.execute(CMU_PICTURE_PROPERTIES);
	
	*width = PA_GetLongintVariable(args[1]);
	*height = PA_GetLongintVariable(args[2]);	
	
}

PA_Picture CPicture::createThumbnail(unsigned int width, unsigned int height)
{
	PA_Picture p;
	PictureArguments args(4);
	args[1] = PA_CreateVariable(eVK_Picture);	
	args[2] = PA_CreateVariable(eVK_Longint);		
	args[3] = PA_CreateVariable(eVK_Longint);	
	
	PA_SetPictureVariable(&args[0], PA_DuplicatePicture(this->_CPicture, 1));
	PA_SetLongintVariable(&args[2], width);
	PA_SetLongintVariable(&args[3], height);	
	
	args.execute(CMU_CREATE_THUMBNAIL);
	
	p = PA_GetPictureVariable(args[1]);
	
	PA_SetPictureVariable(&args[1], NULL);		
	
	return p;
}

CPicture::CPicture() : _CBytes(new CBytes)
{
	this->_CPicture = PA_CreatePicture(NULL, 0);
	this->_Count = 0;
	this->_TypeNum = 0;
	this->_Type = CUTF8String();
	this->_CBytes->setBytes(NULL, 0);
}

CPicture::~CPicture()
{
	PA_DisposePicture(this->_CPicture);
	delete _CBytes; 
}

void C_PICTURE::fromParamAtIndex(PackagePtr pParams, uint32_t index)
{
	this->_CPicture->fromParamAtIndex(pParams, index);
}

void C_PICTURE::toParamAtIndex(PackagePtr pParams, uint32_t index)
{
	this->_CPicture->toParamAtIndex(pParams, index);
}

void C_PICTURE::setReturn(sLONG_PTR *pResult)
{
	this->_CPicture->setReturn(pResult);
}

void C_PICTURE::setBytes(const uint8_t *bytes, uint32_t len)
{
	this->_CPicture->setBytes(bytes, len);	
}

PA_Picture C_PICTURE::getPicture()
{
	return this->_CPicture->getPicture();	
}

void C_PICTURE::setPicture(PA_Picture picture)
{
	return this->_CPicture->setPicture(picture);	
}

void C_PICTURE::fromFileAtPath(CUTF8String *pFilePath)
{
	this->_CPicture->fromFileAtPath(pFilePath);		
}

const uint8_t *C_PICTURE::getBytesPtr(CUTF8String *pType)
{	
	return this->_CPicture->getBytesPtr(pType);		
}

uint32_t C_PICTURE::getBytesLength(CUTF8String *pType)
{
	return this->_CPicture->getBytesLength(pType);	
}

PA_Picture C_PICTURE::createGrayScale()
{
	return this->_CPicture->createGrayScale();	
}

PA_Picture C_PICTURE::createCopyPNG()
{
    return this->_CPicture->createCopy(".png");	
}

PA_Picture C_PICTURE::createCopyJPG()
{
    return this->_CPicture->createCopy(".jpg");	
}

PA_Picture C_PICTURE::createCopyTIF()
{
    return this->_CPicture->createCopy(".tif");	
}

#if VERSIONMAC
#ifdef __OBJC__	
NSImage* C_PICTURE::copyImage()
{
    return this->_CPicture->copyImage();	
} 

void C_PICTURE::setImage(NSImage *image)
{
    this->_CPicture->setImage(image);	
} 
#endif
#endif

void C_PICTURE::getSize(unsigned int *width, unsigned int *height)
{
	this->_CPicture->getSize(width, height);	
}

PA_Picture C_PICTURE::createThumbnail(unsigned int width, unsigned int height)
{
	return this->_CPicture->createThumbnail(width, height);
}

C_PICTURE::C_PICTURE() : _CPicture(new CPicture)
{
	
}

C_PICTURE::~C_PICTURE()
{ 
	delete _CPicture; 
}