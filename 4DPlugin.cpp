/* --------------------------------------------------------------------------------
 #
 #	4DPlugin.cpp
 #	source generated by 4D Plugin Wizard
 #	Project : Tesseract
 #	author : miyako
 #	2019/02/25
 #
 # --------------------------------------------------------------------------------*/

#include "4DPlugin.h"

void PluginMain(PA_long32 selector, PA_PluginParameters params){
	try
	{
		PA_long32 pProcNum = selector;
		sLONG_PTR *pResult = (sLONG_PTR *)params->fResult;
		PackagePtr pParams = (PackagePtr)params->fParameters;

		CommandDispatcher(pProcNum, pResult, pParams); 
	}
	catch(...)
	{

	}
}

void CommandDispatcher (PA_long32 pProcNum, sLONG_PTR *pResult, PackagePtr pParams){
	switch(pProcNum)
	{
// --- Tesseract

		case 1 :
			Tesseract_Get_info(pResult, pParams);
			break;
            
        case 2 :
            Tesseract(pResult, pParams);
            break;
	}
}

// ----------------------------------- Tesseract ----------------------------------

void convertFromString(std::string &fromString, CUTF16String &toString){
#ifdef _WIN32
    int len = MultiByteToWideChar(CP_UTF8, 0, (LPCSTR)fromString.c_str(), fromString.length(), NULL, 0);
    
    if(len){
        std::vector<uint8_t> buf((len + 1) * sizeof(PA_Unichar));
        if(MultiByteToWideChar(CP_UTF8, 0, (LPCSTR)fromString.c_str(), fromString.length(), (LPWSTR)&buf[0], len)){
            toString = CUTF16String((const PA_Unichar *)&buf[0]);
        }
    }else{
        toString = CUTF16String((const PA_Unichar *)L"\0\0");
    }
#else
    CFStringRef str = CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)fromString.c_str(), fromString.length(), kCFStringEncodingUTF8, true);
    if(str){
        int len = CFStringGetLength(str);
        std::vector<uint8_t> buf((len+1) * sizeof(PA_Unichar));
        CFStringGetCharacters(str, CFRangeMake(0, len), (UniChar *)&buf[0]);
        toString = CUTF16String((const PA_Unichar *)&buf[0]);
        CFRelease(str);
    }
#endif
}

void setJsonReturnValue(C_TEXT& returnValue, Json::Value& value){
    Json::StyledWriter writer;
    std::string valueString = writer.write(value);
    CUTF16String valueStringUnicode;
    convertFromString(valueString, valueStringUnicode);
    returnValue.setUTF16String(&valueStringUnicode);
}

static void Win32ErrorHandler(const char* module, const char* fmt, va_list ap) {
    if (module != nullptr) {
        fprintf(stderr, "%s: ", module);
    }
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, ".\n");
}

static void Win32WarningHandler(const char* module, const char* fmt, va_list ap) {
    if (module != nullptr) {
        fprintf(stderr, "%s: ", module);
    }
    fprintf(stderr, "Warning, ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, ".\n");
}

void Tesseract_Get_info(sLONG_PTR *pResult, PackagePtr pParams){
	C_TEXT returnValue;
    Json::Value info;
    
    /* tesseract */
    info["version"] = tesseract::TessBaseAPI::Version();
    info["SIM"] = Json::objectValue;
    info["SIM"]["isAVX512BWAvailable"] = tesseract::SIMDDetect::IsAVX512BWAvailable();
    info["SIM"]["isAVX512FAvailable"] = tesseract::SIMDDetect::IsAVX512FAvailable();
    info["SIM"]["isAVX2Available"] = tesseract::SIMDDetect::IsAVX2Available();
    info["SIM"]["isAVXAvailable"] = tesseract::SIMDDetect::IsAVXAvailable();
    info["SIM"]["isSSEAvailable"] = tesseract::SIMDDetect::IsSSEAvailable();
    
    /* leptonica */
    char* leptonicaVersion;
    leptonicaVersion = getLeptonicaVersion();
    info["leptonica"] = leptonicaVersion;
    lept_free(leptonicaVersion);
    
    char* imageLibraryVersions;
    imageLibraryVersions = getImagelibVersions();
    info["libraries"] = imageLibraryVersions;
    lept_free(imageLibraryVersions);
    
    setJsonReturnValue(returnValue, info);
	returnValue.setReturn(pResult);
}

bool json_parse(C_TEXT& Param, Json::Value& node){
    CUTF8String u8;
    Param.copyUTF8String(&u8);
    
    Json::CharReaderBuilder builder;
    std::string errors;
    
    Json::CharReader *reader = builder.newCharReader();
    bool parse = reader->parse((const char *)u8.c_str(),
                               (const char *)u8.c_str() + u8.size(),
                               &node,
                               &errors);
    delete reader;
    
    return parse;
}

typedef enum {

    TESSERACT_OPTION_UNDEFINED = 0,
    TESSERACT_OPTION_LANGUAGE = 1,
    TESSERACT_OPTION_TESSDATA_PREFIX = 2,
    TESSERACT_OPTION_FORMAT = 3,
    TESSERACT_OPTION_PAGE = 4,
    TESSERACT_OPTION_OEM = 5,
    TESSERACT_OPTION_CLEAR_GLOBAL_CACHE = 6
    
}tesseract_option_t;

typedef enum {
    
    TESSERACT_FORMAT_UNDEFINED = 0,
    TESSERACT_FORMAT_GIF  = 1,
    TESSERACT_FORMAT_TIFF = 2,
    TESSERACT_FORMAT_PNG  = 3,
    TESSERACT_FORMAT_BMP  = 4,
    TESSERACT_FORMAT_WEBP = 5,
    TESSERACT_FORMAT_PNM  = 6,
    TESSERACT_FORMAT_JPEG = 7
    
}tesseract_format_t;

char easytolower(char in) {
    if(in <= 'Z' && in >= 'A')
        return in - ('Z' - 'z');
    return in;
}

tesseract_format_t get_tesseract_format(JSONCPP_STRING s){
#define CHECKOPT(__a,__b) if(s==__a){v=(tesseract_format_t)__b;goto get_tesseract_format_exit;}
    
    tesseract_format_t v = TESSERACT_FORMAT_UNDEFINED;
    
    if (s.length())
    {
        std::transform(s.begin(), s.end(), s.begin(), easytolower);
        
        CHECKOPT(".gif",TESSERACT_FORMAT_GIF)
        CHECKOPT(".tif",TESSERACT_FORMAT_TIFF)
        CHECKOPT(".png",TESSERACT_FORMAT_PNG)
        CHECKOPT(".pnm",TESSERACT_FORMAT_PNM)
        CHECKOPT(".bmp",TESSERACT_FORMAT_BMP)
        CHECKOPT(".jpg",TESSERACT_FORMAT_JPEG)
        CHECKOPT(".tiff",TESSERACT_FORMAT_TIFF)
        CHECKOPT(".webp",TESSERACT_FORMAT_WEBP)
        CHECKOPT(".jpeg",TESSERACT_FORMAT_JPEG)
        
    get_tesseract_format_exit:
        (void)0;
    }
    
    return v;
}

tesseract_option_t get_tesseract_option(Json::Value::const_iterator n){
    #define CHECKOPT(__a,__b) if(s==__a){v=(tesseract_option_t)__b;goto get_tesseract_option_exit;}

    tesseract_option_t v = TESSERACT_OPTION_UNDEFINED;
    
    JSONCPP_STRING s = n.name();
    
    if (s.length())
    {
        CHECKOPT("lang",TESSERACT_OPTION_LANGUAGE)
        CHECKOPT("tessdata",TESSERACT_OPTION_TESSDATA_PREFIX)
        CHECKOPT("format",TESSERACT_OPTION_FORMAT)
        CHECKOPT("page",TESSERACT_OPTION_PAGE)
        CHECKOPT("oem",TESSERACT_OPTION_OEM)
        CHECKOPT("clearGlobalCache",TESSERACT_OPTION_CLEAR_GLOBAL_CACHE)
        
    get_tesseract_option_exit:
        (void)0;
    }

    return v;
}

JSONCPP_STRING convertPath(const char *path){
    JSONCPP_STRING convertedPath;
    #if VERSIONMAC
    if(path)
    {
        NSString *s = [[NSString alloc]initWithUTF8String:path];
        if(s)
        {
            NSURL *u = (NSURL *)CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)s, kCFURLHFSPathStyle, false);
            if(u){
                NSString *p = (NSString *)CFURLCopyFileSystemPath((CFURLRef)u, kCFURLPOSIXPathStyle);
                if(p)
                {
                    CFIndex size = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)p);
                    std::vector<uint8_t> buf(size);
                    [p getFileSystemRepresentation:(char *)&buf[0] maxLength:size];
                    convertedPath = JSONCPP_STRING((char *)&buf[0]);
                    if(convertedPath.at(convertedPath.size() - 1) != '/')
                        convertedPath += '/';
                    [p release];
                }
                [u release];
            }
            [s release];
        }
        
    }
    #endif
    return convertedPath;
}

void readImage(tesseract::TessBaseAPI *api,
               Pix *image,
               Json::Value& value,
               Json::ArrayIndex i,
               void (*_PA_YieldAbsolute)(void), size_t interval);
    
void Tesseract(sLONG_PTR *pResult, PackagePtr pParams)
{
    /* Show libtiff errors and warnings on console (not in GUI). */
    TIFFSetErrorHandler(Win32ErrorHandler);
    TIFFSetWarningHandler(Win32WarningHandler);

    FOURD::C_BLOB Param1;
    C_TEXT Param2;
    C_TEXT returnValue;
    
    Param1.fromParamAtIndex(pParams, 1);
    Param2.fromParamAtIndex(pParams, 2);
    
    tesseract::Dict::GlobalDawgCache();
    tesseract::TessBaseAPI api;
    
    JSONCPP_STRING lang = "eng";
    JSONCPP_STRING tessdata;
    
    tesseract_format_t format = TESSERACT_FORMAT_UNDEFINED;
    tesseract::OcrEngineMode oem = tesseract::OEM_DEFAULT;
    
#define TESSERACT_ALL_PAGES (-1)
    
    int page = TESSERACT_ALL_PAGES;
    bool clearGlobalCache = false;
    
    Json::Value root;
    
    std::vector<JSONCPP_STRING> optionNames;
    std::vector<JSONCPP_STRING> optionValues;
    
    if(json_parse(Param2, root))
    {
        if(root.isObject())
        {
            for(Json::Value::const_iterator it = root.begin() ; it != root.end() ; it++)
            {
                switch (get_tesseract_option(it)) {
                    case TESSERACT_OPTION_LANGUAGE:
                        lang = it->asString();
                        break;
                    case TESSERACT_OPTION_TESSDATA_PREFIX:
                        tessdata = convertPath(it->asString().c_str());
                        break;
                    case TESSERACT_OPTION_FORMAT:
                        format = get_tesseract_format(it->asString());
                        break;
                    case TESSERACT_OPTION_PAGE:
                        page = it->asInt();
                        break;
                    case TESSERACT_OPTION_OEM:
                        oem = (tesseract::OcrEngineMode)(it->asUInt() < tesseract::OEM_COUNT ? it->asUInt() : tesseract::OEM_DEFAULT);
                        break;
                        
                    case TESSERACT_OPTION_CLEAR_GLOBAL_CACHE:
                        clearGlobalCache = it->asBool();
                        break;
                        
                    default:
                    {
                        optionNames.push_back(it.name());
                        optionValues.push_back(it->asString());
                    }
                        break;
                }
            }
        }
    }
    
    if(clearGlobalCache)
    {
        api.ClearPersistentCache();
    }
        
    int err = api.Init(tessdata.c_str(), lang.c_str(), oem);
 
    if(!err){
        
        for(size_t i = 0 ; i < optionNames.size() ; ++i)
        {
            const char *name = optionNames.at(i).c_str();
            const char *value = optionValues.at(i).c_str();
            api.SetVariable(name, value);
        }

        root["languages"] = Json::objectValue;
        root["languages"]["available"] = Json::arrayValue;
        root["languages"]["loaded"] = Json::arrayValue;
        
        GenericVector<STRING> languages;
        
        api.GetAvailableLanguagesAsVector(&languages);
        for (int i = 0; i < languages.size(); ++i) {
            STRING& string = languages[i];
            root["languages"]["available"][i] = string.string();
        }
        
        api.GetLoadedLanguagesAsVector(&languages);
        for (int i = 0; i < languages.size(); ++i) {
            STRING& string = languages[i];
            root["languages"]["loaded"][i] = string.string();
        }
        
        Json::Value result;
        
        Pix *image = NULL;
        Pixa *images = NULL;
        
        const l_uint8 *data = (const l_uint8 *)Param1.getBytesPtr();
        size_t size = (size_t)Param1.getBytesLength();
        
        switch (format) {
            case TESSERACT_FORMAT_TIFF:
                if(page == TESSERACT_ALL_PAGES)
                {
                    images = pixaReadMemMultipageTiff(data, size);
                }else{
                    image = pixReadMemTiff (data, size, page);
                }
                break;
                
            case TESSERACT_FORMAT_PNM:
                image = pixReadMemPnm(data, size);
            case TESSERACT_FORMAT_PNG:
                image = pixReadMemPng(data, size);
            case TESSERACT_FORMAT_GIF:
                image = pixReadMemGif(data, size);
            case TESSERACT_FORMAT_BMP:
                image = pixReadMemBmp(data, size);
            case TESSERACT_FORMAT_WEBP:
                image = pixReadMemWebP(data, size);
            case TESSERACT_FORMAT_JPEG:
                image = pixReadMemJpeg(data, size, 0, 1, NULL, 0);
                
            default:
                image = pixReadMem(data, size);
                break;
        }
        
        void (*_PA_YieldAbsolute)(void) = PA_YieldAbsolute;
        
        result["results"] = Json::arrayValue;
        
        if((images) && (images->n))
        {
            for(int i = 0; i < images->n;++i)
            {
                readImage(&api, images->pix[i],
                          result["results"],
                          i,
                          _PA_YieldAbsolute, 0x0001);
            }
            
        }else if(image)
        {
            readImage(&api, image,
                      result["results"],
                      0,
                      _PA_YieldAbsolute, 0x0001);
        }
        
        setJsonReturnValue(returnValue, result);
        
        api.End();
        
        setJsonReturnValue(Param2, root);
        Param2.toParamAtIndex(pParams, 2);
    }
    
    returnValue.setReturn(pResult);
}

void readImage(tesseract::TessBaseAPI *api, Pix *image, Json::Value& value, Json::ArrayIndex i,
       void (*_PA_YieldAbsolute)(void), size_t interval){
    
    if(api)
    {
        if(image)
        {
            if(value.isArray())
            {
                api->SetImage(image);
                
                char *t = api->GetUTF8Text(_PA_YieldAbsolute, interval);
                value[i] = Json::objectValue;
                value[i]["text"] = t;
                delete [] t;
            }
            pixDestroy(&image);
        }

    }
  
}
