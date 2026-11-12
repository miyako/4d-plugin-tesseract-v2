#include "4DPlugin.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#import <objc/runtime.h>
#include <iostream>
#include <set>
#include <type_traits>
#include <cstring>
#include <cstdio>

void convertFromString(std::string&, CUTF16String&);

namespace fixture {
std::string text = "ASCII";
int mode = 0, calls = 0, images = 0, boxes = 0, iterators = 0, texts = 0;
}
namespace {
using Text = std::basic_string<PA_Unichar>;
std::map<PA_Unichar*, Text> strings;
std::map<PA_Handle, size_t> handles;
std::map<PA_Picture, int> pictures;
int checks = 0, failures = 0, invalidDisposals = 0, pointerReads = 0;
bool failResize = false, failHandle = false, failPicture = false, failConvert = false;
bool failData = false;
int failCommand = 0, resultKind = 0, invalidResults = 0;
Text pictureFormat;
PA_Unistring formatDescriptor = {};

void require(bool ok) {
    if (!ok) throw std::runtime_error("unexpected synthetic operation");
}
void check(bool ok, const std::string& name) {
    ++checks;
    std::cout << (ok ? "PASS " : "FAIL ") << name << "\n";
    if (!ok) ++failures;
}
Text text(const char* s) {
    NSString* str = [NSString stringWithUTF8String:s];
    Text out([str length], 0);
    if (!out.empty()) [str getCharacters:&out[0] range:NSMakeRange(0, out.size())];
    return out;
}
PA_Unistring make(const PA_Unichar* p) {
    Text t(p ? p : reinterpret_cast<const PA_Unichar*>(u""));
    PA_Unistring s = {};
    s.fLength = static_cast<PA_long32>(t.size());
    s.fString = new PA_Unichar[t.size() + 1];
    std::copy(t.begin(), t.end(), s.fString); s.fString[t.size()] = 0;
    strings.emplace(s.fString, t); return s;
}
void dispose(PA_Unistring s) {
    if (!s.fString) return;
    if (!strings.erase(s.fString)) { ++invalidDisposals; return; }
    delete[] s.fString;
}
PA_Picture picture() {
    void* p = new int(0); pictures[p] = 1; return p;
}
void releasePicture(PA_Picture p) {
    if (!p) return;
    if (!pictures.count(p)) { ++invalidDisposals; return; }
    if (--pictures[p] == 0) { pictures.erase(p); delete static_cast<int*>(p); }
}
void freeHandle(PA_Handle h) {
    if (!h) return;
    require(handles.erase(h) == 1); free(*h); delete h;
}
void clear(PA_Variable& v) {
    if (v.fFiller) { v = {}; v.fType = eVK_Undefined; return; }
    switch (PA_GetVariableKind(v)) {
        case eVK_Unistring: dispose(v.uValue.fString); break;
        case eVK_Picture: releasePicture(v.uValue.fPicture); break;
        case eVK_Blob: freeHandle(v.uValue.fBlob.fHandle); break;
        case eVK_ArrayUnicode: {
            auto h = v.uValue.fArray.fData;
            if (h) {
                auto p = reinterpret_cast<PA_Unistring*>(*h);
                require(handles.at(h) >= (v.uValue.fArray.fNbElements + 1) * sizeof(*p));
                for (int i = 0; i <= v.uValue.fArray.fNbElements; ++i) dispose(p[i]);
                freeHandle(h);
            }
            break;
        }
        case eVK_ArrayBoolean: case eVK_ArrayInteger: case eVK_ArrayLongint:
        case eVK_ArrayReal: case eVK_ArrayDate: case eVK_ArrayTime:
            freeHandle(v.uValue.fArray.fData); break;
        default: break;
    }
    v = {}; v.fType = eVK_Undefined;
}
void balance(const std::string& name) {
    check(strings.empty() && pictures.empty() && handles.empty() && !invalidDisposals,
          name + " owner balance");
    // Account first, then isolate known baseline leaks without hiding failures.
    for (auto& s : strings) delete[] s.first;
    strings.clear();
    for (auto& p : pictures) delete static_cast<int*>(p.first);
    pictures.clear();
    require(handles.empty());
    invalidDisposals = 0;
}
void engine(short selector, EngineBlock* eb) {
    eb->fError = 0;
    switch (selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = make(reinterpret_cast<PA_Unichar*>(eb->fHandle)); break;
        case EX_DISPOSE_UNISTRING: dispose(eb->fUniString1); break;
        case EX_SET_UNISTRING: {
            PA_Unistring s = make(reinterpret_cast<PA_Unichar*>(eb->fHandle));
            dispose(eb->fUniString1); eb->fUniString1 = s; break;
        }
        case EX_CLEAR_VARIABLE:
            if (failCommand && static_cast<PA_Variable*>(eb->fPtr1)->fType == 0)
                ++invalidResults;
            clear(*static_cast<PA_Variable*>(eb->fPtr1)); break;
        case EX_HANDLE_MANAGER: {
            auto h = eb->fHandle;
            switch (eb->fParam1) {
                case 1:
                    if (failHandle) { eb->fError = -1; eb->fHandle = nullptr; break; }
                    h = new char*;
                    *h = static_cast<char*>(calloc(1, std::max<sLONG_PTR>(1, eb->fParam2)));
                    handles[h] = eb->fParam2; eb->fHandle = h; break;
                case 2: freeHandle(h); break;
                case 3:
                    if (failResize) { eb->fError = -1; break; }
                    *h = static_cast<char*>(realloc(*h, std::max<sLONG_PTR>(1, eb->fParam2)));
                    handles[h] = eb->fParam2; break;
                case 4: case 5:
                    if (!handles.count(h)) {
                        // The bundled SDK forwards these without a null guard.
                        fprintf(stderr, "SYNTHETIC-DEFECT unowned handle use op=%d null=%d\n",
                                static_cast<int>(eb->fParam1), h == nullptr);
                        abort();
                    }
                    if (eb->fParam1 == 4) eb->fParam2 = handles.at(h);
                    else eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h);
                    break;
                case 6: break;
                default: throw std::runtime_error("unexpected handle operation");
            }
            break;
        }
        case EX_CREATE_PICTURE:
            if (failPicture) { eb->fError = -1; eb->fPicture = reinterpret_cast<void*>(1); }
            else {
                if (eb->fParam1) require(eb->fParam1 == 3 && !memcmp(eb->fPtr1, "IMG", 3));
                eb->fPicture = picture();
            }
            break;
        case EX_DISPOSE_PICTURE: releasePicture(eb->fPicture); break;
        case EX_DUPLICATE_PICTURE:
            require(pictures.count(eb->fPicture));
            if (eb->fParam1) eb->fPicture = picture();
            else ++pictures.at(eb->fPicture);
            break;
        case EX_GET_PICTURE_DATA:
            require(pictures.count(eb->fPicture));
            if (eb->fParam1 > 1 || (eb->fHandle && failData)) {
                eb->fError = -1;
                // Deliberately unspecified failed descriptor. Never inspect it.
                memset(&eb->fUniString1, 0xA5, sizeof(eb->fUniString1));
            } else {
                // Metadata ownership is not established by this SDK; this fixture
                // exposes a borrowed descriptor and does not claim that contract.
                eb->fUniString1 = formatDescriptor;
                if (eb->fHandle) {
                    PA_SetHandleSize(eb->fHandle, 3);
                    memcpy(*eb->fHandle, "IMG", 3);
                }
            }
            break;
        case EX_CONVERT_CHARSET_TO_CHARSET: {
            if (failConvert) { eb->fError = -1; eb->fParam3 = -1; break; }
            CFStringEncoding in = eb->fParam2 == eVTC_UTF_8 ? kCFStringEncodingUTF8 : kCFStringEncodingUTF16LE;
            CFStringEncoding out = eb->fParam4 == eVTC_UTF_8 ? kCFStringEncodingUTF8 : kCFStringEncodingUTF16LE;
            CFStringRef s = CFStringCreateWithBytes(nullptr, static_cast<const UInt8*>(eb->fPtr1),
                                                  eb->fParam1, in, false);
            require(s != nullptr);
            CFIndex used = 0;
            CFIndex converted = CFStringGetBytes(s, CFRangeMake(0, CFStringGetLength(s)),
                out, 0, false, static_cast<UInt8*>(eb->fPtr2), eb->fParam3, &used);
            require(converted == CFStringGetLength(s));
            CFRelease(s); eb->fParam3 = used; break;
        }
        case EX_EXECUTE_COMMAND_BY_ID: {
            auto result = static_cast<PA_Variable*>(eb->fPtr2);
            if (eb->fParam1 == failCommand) {
                memset(result, 0xA5, sizeof(*result)); result->fType = 0;
                eb->fError = -1; break;
            }
            auto args = static_cast<PA_Variable**>(eb->fPtr1);
            switch (eb->fParam1) {
                case 678:
                    require(strings.count(args[0]->uValue.fString.fString));
                    clear(*args[1]); PA_SetPictureVariable(args[1], picture()); break;
                case 1002:
                    pictureFormat = Text(args[1]->uValue.fString.fString,
                                         args[1]->uValue.fString.fLength);
                    break;
                case 988: break;
                case 457: PA_SetLongintVariable(args[1], 3); PA_SetLongintVariable(args[2], 4); break;
                case 679:
                    clear(*args[1]); PA_SetPictureVariable(args[1], picture()); break;
                default: throw std::runtime_error("unexpected command");
            }
            *result = PA_CreateVariable(eVK_Undefined);
            if (resultKind == 1 || resultKind == 3) {
                auto s = make(text("result").c_str()); PA_SetStringVariable(result, &s);
                if (resultKind == 3) result->fType = 0;
            } else if (resultKind == 2) PA_SetPictureVariable(result, picture());
            break;
        }
        case EX_GET_POINTER_VALUE:
            ++pointerReads;
            *reinterpret_cast<PA_Variable*>(eb->fHandle) = PA_CreateVariable(eVK_Unistring);
            break;
        case EX_GET_POINTER_VALUE_PROPERTIES:
            eb->fParam1 = eVK_Unistring; eb->fParam2 = 0; eb->fParam3 = 0; break;
        case EX_GET_INFORMATION: require(eb->fParam3 == 'FAST'); eb->fParam1 = 0; break;
        case EX_YIELD_ABSOLUTE: break;
        default: throw std::runtime_error("unexpected host selector " + std::to_string(selector));
    }
}
void denyApple(id, SEL, ...) { throw std::runtime_error("external Apple selector prohibited"); }
void deny(Class c, const char* name, bool classMethod = false) {
    Method m = classMethod ? class_getClassMethod(c, sel_registerName(name)) :
                             class_getInstanceMethod(c, sel_registerName(name));
    require(m); method_setImplementation(m, reinterpret_cast<IMP>(denyApple));
}
template<class T> void noCopy(const char* name) {
    check(!std::is_copy_constructible<T>::value && !std::is_copy_assignable<T>::value,
          std::string(name) + " rejects shallow owner copies");
}
void dispatch(int n, std::initializer_list<void*> args, PA_Unistring& out) {
    std::vector<uint8_t*> p;
    for (void* a : args) p.push_back(static_cast<uint8_t*>(a));
    PA_Unistring* result = &out;
    FourDPackex(n, p.data(), nullptr, &result);
}
void seed(ARRAY_TEXT& a) { CUTF16String t = text("value"); a.setUTF16StringAtIndex(&t, 0); }
bool matches(ARRAY_TEXT& a) { CUTF16String t; a.copyUTF16StringAtIndex(&t, 0); return t == text("value"); }
void seed(ARRAY_BOOLEAN& a) { a.setBooleanValueAtIndex(true, 0); }
bool matches(ARRAY_BOOLEAN& a) { return a.getBooleanValueAtIndex(0); }
void seed(ARRAY_INTEGER& a) { a.setShortValueAtIndex(-7, 0); }
bool matches(ARRAY_INTEGER& a) { return a.getShortValueAtIndex(0) == -7; }
void seed(ARRAY_LONGINT& a) { a.setIntValueAtIndex(123, 0); }
bool matches(ARRAY_LONGINT& a) { return a.getIntValueAtIndex(0) == 123; }
void seed(ARRAY_REAL& a) { a.setDoubleValueAtIndex(1.5, 0); }
bool matches(ARRAY_REAL& a) { return a.getDoubleValueAtIndex(0) == 1.5; }
void seed(ARRAY_TIME& a) { a.setTimeValueAtIndex(77, 0); }
bool matches(ARRAY_TIME& a) { return a.getTimeValueAtIndex(0) == 77; }
void seed(ARRAY_DATE& a) { a.setYearMonthDayAtIndex(2026, 11, 12, 0); }
bool matches(ARRAY_DATE& a) {
    uint16_t y = 0, m = 0, d = 0; a.getYearMonthDayAtIndex(&y, &m, &d, 0);
    return y == 2026 && m == 11 && d == 12;
}
template<class T> void arrayCases(PA_VariableKind kind, const char* name) {
    std::string label(name);
    {
        T t; t.setSize(9); seed(t);
        PA_Variable a = PA_CreateVariable(eVK_Undefined);
        uint8_t* args[] = {reinterpret_cast<uint8_t*>(&a)};
        t.toParamAtIndex(args, 1);
        check(a.fType == kind && a.uValue.fArray.fNbElements == 8,
              label + " undefined output metadata");
        T input; input.fromParamAtIndex(args, 1);
        check(input.getSize() == 9, label + " input snapshot");
        check(matches(input), label + " scalar content roundtrip including zero");
        t.toParamAtIndex(args, 1);
        t.setSize(1); t.toParamAtIndex(args, 1);
        check(a.uValue.fArray.fNbElements == 0, label + " repeated output and shrink");
        PA_ClearVariable(&a);
    }
    balance(label);
    PA_Variable bad = PA_CreateVariable(eVK_Longint);
    uint8_t* args[] = {reinterpret_cast<uint8_t*>(&bad)};
    T t; t.setSize(2); bool reported = false;
    try { t.toParamAtIndex(args, 1); } catch (const std::runtime_error&) { reported = true; }
    check(reported && bad.fType == eVK_Longint, label + " wrong kind reported");
    PA_Variable nullArray = {};
    nullArray.fType = kind; args[0] = reinterpret_cast<uint8_t*>(&nullArray);
    reported = false;
    try { t.toParamAtIndex(args, 1); } catch (const std::runtime_error&) { reported = true; }
    check(reported, label + " null output storage reported");
    balance(label + " rejected output");
}
template<class T> int isolatedArray(PA_VariableKind kind, const std::string& mode) {
    PA_Variable a = PA_CreateVariable(kind);
    uint8_t* args[] = {reinterpret_cast<uint8_t*>(&a)};
    T t; t.setSize(100);
    bool reported = false;
    if (mode == "null") {
        PA_ClearVariable(&a); a = {}; a.fType = kind;
        try { t.fromParamAtIndex(args, 1); } catch (const std::runtime_error&) { reported = true; }
        check(reported, "null input storage reported");
    } else {
        failResize = true;
        try { t.toParamAtIndex(args, 1); } catch (const std::runtime_error&) { reported = true; }
        failResize = false;
        check(reported && a.uValue.fArray.fNbElements == 0,
              "resize failure reported before writing or publishing count");
        PA_ClearVariable(&a);
    }
    balance("isolated " + mode);
    return failures ? 1 : 0;
}
}

extern "C" CFURLRef CFURLCreateWithFileSystemPath(CFAllocatorRef, CFStringRef, CFURLPathStyle, Boolean) {
    throw std::runtime_error("path operations prohibited");
}
extern "C" CFStringRef CFURLCopyFileSystemPath(CFURLRef, CFURLPathStyle) {
    throw std::runtime_error("path operations prohibited");
}
extern "C" CFIndex CFStringGetMaximumSizeOfFileSystemRepresentation(CFStringRef) {
    throw std::runtime_error("path operations prohibited");
}
extern "C" FILE* ownership_fopen(const char*, const char*) {
    throw std::runtime_error("file operations prohibited");
}
extern "C" int ownership_fclose(FILE*) { throw std::runtime_error("file operations prohibited"); }
extern "C" void CGContextScaleCTM(CGContextRef, CGFloat, CGFloat) {
    throw std::runtime_error("drawing operations prohibited");
}
extern "C" void CGContextTranslateCTM(CGContextRef, CGFloat, CGFloat) {
    throw std::runtime_error("drawing operations prohibited");
}
extern "C" TIFFErrorHandler TIFFSetErrorHandler(TIFFErrorHandler) { return nullptr; }
extern "C" TIFFErrorHandler TIFFSetWarningHandler(TIFFErrorHandler) { return nullptr; }
extern "C" char* getLeptonicaVersion() { return strdup("synthetic-leptonica"); }
extern "C" char* getImagelibVersions() { return strdup("synthetic-codecs"); }
extern "C" void lept_free(void* p) { free(p); }
static PIX* syntheticImage(const l_uint8* p, size_t n) {
    require(n == 3 && p && !memcmp(p, "IMG", 3));
    ++fixture::images; return new PIX();
}
#define MEMORY_READER(name) \
extern "C" PIX* name(const l_uint8* p, size_t n) { return syntheticImage(p, n); }
MEMORY_READER(pixReadMem)
MEMORY_READER(pixReadMemPng)
MEMORY_READER(pixReadMemPnm)
MEMORY_READER(pixReadMemBmp)
MEMORY_READER(pixReadMemGif)
MEMORY_READER(pixReadMemWebP)
extern "C" PIX* pixReadMemTiff(const l_uint8* p, size_t n, l_int32) { return syntheticImage(p, n); }
extern "C" PIX* pixReadMemJpeg(const l_uint8* p, size_t n, l_int32, l_int32, l_int32*, l_int32) {
    return syntheticImage(p, n);
}
#define STREAM_READER(name) \
extern "C" PIX* name(FILE*) { throw std::runtime_error("stream operations prohibited"); }
STREAM_READER(pixReadStreamPng)
STREAM_READER(pixReadStreamPnm)
STREAM_READER(pixReadStreamBmp)
STREAM_READER(pixReadStreamGif)
STREAM_READER(pixReadStreamWebP)
extern "C" PIX* pixReadStreamTiff(FILE*, l_int32) { throw std::runtime_error("stream prohibited"); }
extern "C" PIX* pixReadStreamJpeg(FILE*, l_int32, l_int32, l_int32*, l_int32) {
    throw std::runtime_error("stream prohibited");
}
extern "C" PIX* pixRead(const char*) { throw std::runtime_error("file prohibited"); }
extern "C" PIXA* pixaReadMultipageTiff(const char*) { throw std::runtime_error("file prohibited"); }
extern "C" PIXA* pixaReadMemMultipageTiff(const l_uint8* p, size_t n) {
    PIXA* a = new PIXA(); a->n = 2; a->pix = new PIX*[2];
    a->pix[0] = syntheticImage(p, n); a->pix[1] = syntheticImage(p, n); return a;
}
extern "C" void pixDestroy(PIX** p) { if (*p) { --fixture::images; delete *p; *p = nullptr; } }
extern "C" void pixaDestroy(PIXA** a) {
    for (int i = 0; i < (*a)->n; ++i) pixDestroy(&(*a)->pix[i]);
    delete[] (*a)->pix; delete *a; *a = nullptr;
}
BOXA* tesseract::TessBaseAPI::GetComponentImages(PageIteratorLevel, bool, void*, void*) {
    BOXA* a = new BOXA(); a->n = 1; a->box = new BOX*[1];
    a->box[0] = new BOX(); a->box[0]->w = 3; a->box[0]->h = 4;
    a->box[0]->refcount = 1; ++fixture::boxes; return a;
}
extern "C" BOX* boxaGetBox(BOXA* a, l_int32 i, l_int32 mode) {
    require(i == 0 && mode == L_CLONE); ++a->box[0]->refcount; return a->box[0];
}
extern "C" void boxDestroy(BOX** b) {
    if (--(*b)->refcount == 0) { --fixture::boxes; delete *b; } *b = nullptr;
}
extern "C" void boxaDestroy(BOXA** a) {
    for (int i = 0; i < (*a)->n; ++i) boxDestroy(&(*a)->box[i]);
    delete[] (*a)->box; delete *a; *a = nullptr;
}

void pictureBytesFailure(bool allocation) {
    {
        C_PICTURE p; p.setBytes(reinterpret_cast<const uint8_t*>("IMG"), 3);
        CUTF8String type(reinterpret_cast<const uint8_t*>(".png"));
        bool reported = false; failData = !allocation; failHandle = allocation;
        try { reported = p.getBytesLength(&type) == 0 && !allocation; }
        catch (const std::runtime_error& e) {
            reported = allocation && std::string(e.what()).find("-1") != std::string::npos;
        }
        failData = false; failHandle = false;
        check(reported, allocation ? "picture byte handle allocation failure reported" :
                                    "picture data failure returns no bytes");
        check(p.getBytesLength(&type) == 3 && !memcmp(p.getBytesPtr(&type), "IMG", 3),
              allocation ? "picture byte cache retries after allocation failure" :
                           "picture byte cache retries after data failure");
    }
    balance(allocation ? "picture failed allocation" : "picture failed data");
}

int main(int argc, char** argv) {
    @autoreleasepool {
        deny([NSURL class], "initWithString:");
        deny([NSURL class], "initFileURLWithPath:");
        deny([NSData class], "initWithContentsOfFile:");
        deny([NSImage class], "initWithCGImage:size:");
        deny([NSImage class], "TIFFRepresentation");
        deny([NSString class], "getFileSystemRepresentation:maxLength:");
        gCall4D = engine;
        pictureFormat = text(".png");
        formatDescriptor.fString = const_cast<PA_Unichar*>(pictureFormat.c_str());
        formatDescriptor.fLength = pictureFormat.size();
        if (argc == 3) {
            const std::string name = argv[2], mode = argv[1];
#define ISOLATE(type, kind) if (name == #type) return isolatedArray<type>(kind, mode);
            ISOLATE(ARRAY_TEXT, eVK_ArrayUnicode)
            ISOLATE(ARRAY_BOOLEAN, eVK_ArrayBoolean)
            ISOLATE(ARRAY_INTEGER, eVK_ArrayInteger)
            ISOLATE(ARRAY_LONGINT, eVK_ArrayLongint)
            ISOLATE(ARRAY_REAL, eVK_ArrayReal)
            ISOLATE(ARRAY_DATE, eVK_ArrayDate)
            ISOLATE(ARRAY_TIME, eVK_ArrayTime)
            throw std::runtime_error("unknown isolated case");
        }
        if (argc == 2 && std::string(argv[1]) == "--picture-allocation") {
            pictureBytesFailure(true);
            std::cout << "checks=" << checks << " failures=" << failures << "\n";
            return failures ? 1 : 0;
        }
        if (argc == 2 && std::string(argv[1]) == "--picture-copy") {
            for (const char* type : {".png", "\xc3\xa9", "\xf0\x9f\x98\x80", ""}) {
                { CPicture p; PA_Picture copy = p.createCopy(type);
                  check(pictureFormat == text(type), "picture conversion byte count becomes UTF16 units");
                  PA_DisposePicture(copy); }
                balance("picture copy");
            }
            std::cout << "checks=" << checks << " failures=" << failures << "\n";
            return failures ? 1 : 0;
        }
        noCopy<C_TEXT>("C_TEXT"); noCopy<FOURD::C_BLOB>("C_BLOB");
        noCopy<CPicture>("CPicture"); noCopy<C_PICTURE>("C_PICTURE");
        noCopy<ARRAY_TEXT>("ARRAY_TEXT"); noCopy<ARRAY_BOOLEAN>("ARRAY_BOOLEAN");
        noCopy<ARRAY_INTEGER>("ARRAY_INTEGER"); noCopy<ARRAY_LONGINT>("ARRAY_LONGINT");
        noCopy<ARRAY_REAL>("ARRAY_REAL"); noCopy<ARRAY_DATE>("ARRAY_DATE"); noCopy<ARRAY_TIME>("ARRAY_TIME");
        check(std::is_copy_constructible<CBytes>::value && std::is_copy_constructible<C_DATE>::value,
              "value-only bytes and date copies remain supported");

        const char* values[] = {"", "ASCII", "\xc3\xa9", "\xf0\x9f\x98\x80"};
        for (int v = 0; v < 4; ++v) {
            const char* value = values[v];
            const std::string label = "text-" + std::to_string(v);
            {
                PA_Unistring input = make(text(value).c_str());
                uint8_t* args[] = {reinterpret_cast<uint8_t*>(&input)};
                C_TEXT t; t.fromParamAtIndex(args, 1); dispose(input); input = {};
                CUTF8String u8; t.copyUTF8String(&u8);
                check(std::string(reinterpret_cast<const char*>(u8.data()), u8.size()) == value,
                      label + " scalar borrowed input copied");
                std::string narrow(value); CUTF16String converted;
                convertFromString(narrow, converted);
                check(converted == text(value), label + " actual JSON conversion units");
                t.toParamAtIndex(args, 1);
                check(Text(input.fString, input.fLength) == text(value) && !input.fString[input.fLength],
                      label + " scalar output units and terminator");
                dispose(input);
                ARRAY_TEXT a; a.appendUTF8String(reinterpret_cast<const uint8_t*>(value), strlen(value));
                a.appendUTF16String(text(value).c_str());
                PA_Variable out = PA_CreateVariable(eVK_ArrayUnicode);
                uint8_t* arrayArgs[] = {reinterpret_cast<uint8_t*>(&out)};
                a.toParamAtIndex(arrayArgs, 1); a.toParamAtIndex(arrayArgs, 1);
                auto zero = PA_GetStringInArray(out, 0), one = PA_GetStringInArray(out, 1);
                check(Text(zero.fString, zero.fLength) == text(value) &&
                      Text(one.fString, one.fLength) == text(value) &&
                      zero.fString != one.fString && !one.fString[one.fLength],
                      label + " independent transferred descriptors including zero");
                ARRAY_TEXT snapshot; snapshot.fromParamAtIndex(arrayArgs, 1);
                PA_ClearVariable(&out);
                CUTF16String got; snapshot.copyUTF16StringAtIndex(&got, 1);
                check(got == text(value), label + " array borrowed snapshot survives clear");
                CUTF16String replacement = text("replacement");
                snapshot.setUTF16StringAtIndex(replacement.c_str(), 0);
                snapshot.copyUTF16StringAtIndex(&got, 0);
                check(snapshot.getSize() == 2 && got == replacement, label + " pointer indexed setter replaces");
                PA_Variable other = PA_CreateVariable(eVK_ArrayUnicode);
                auto owned = make(text(value).c_str());
                PA_SetStringInArray(other, -1, &owned);
                check(strings.count(owned.fString), label + " rejected negative index retains owner");
                PA_SetStringInArray(other, 1, &owned);
                check(strings.count(owned.fString), label + " rejected high index retains owner");
                dispose(owned); PA_ClearVariable(&other);
            }
            balance(label);
            for (const char* options : {"{}", "{\"getComponentImages\":true}",
                                       "{\"getWord\":true}", "{\"osd\":true}",
                                       "{\"format\":\".tiff\"}"}) {
                fixture::text = value; fixture::calls = 0;
                PA_Handle h = PA_NewHandle(3); memcpy(*h, "IMG", 3);
                auto input = make(text(options).c_str()); PA_Unistring out = {};
                dispatch(2, {&h, &input}, out);
                std::string result;
                { C_TEXT t; t.setUTF16String(&out); CUTF8String bytes; t.copyUTF8String(&bytes);
                  result.assign(reinterpret_cast<const char*>(bytes.data()), bytes.size()); }
                const std::string opt(options);
                std::string item = "{\"confidence\":95,\"text\":\"" + std::string(value) + "\"}";
                if (opt.find("osd") != std::string::npos)
                    item = "{\"deskew\":0.000000,\"direction\":0,\"order\":0,\"orientation\":0}";
                if (opt.find("getWord") != std::string::npos)
                    item = "[{\"bottom\":4,\"confidence\":95.000000,\"left\":1,\"right\":3,\"text\":\"" +
                           std::string(value) + "\",\"top\":2}]";
                if (opt.find("getComponentImages") != std::string::npos)
                    item = "[{\"confidence\":95,\"height\":4,\"text\":\"" + std::string(value) +
                           "\",\"width\":3,\"x\":0,\"y\":0}]";
                const std::string expected = "{\"results\":[" + item +
                    (opt.find("tiff") != std::string::npos ? "," + item : "") + "]}";
                check(result == expected,
                      label + " exported selector-2 JSON " + options);
                CUTF16String optionResult(input.fString, input.fLength);
                check(optionResult.find(text("\"languages\":{\"available\":[\"eng\"],\"loaded\":[\"eng\"]}")) != Text::npos,
                      label + " exported scalar options output " + options);
                check(fixture::calls == (std::string(options).find("tiff") != std::string::npos ? 2 : 1) &&
                      fixture::images == 0 && fixture::boxes == 0 && fixture::iterators == 0,
                      label + " exported synthetic OCR lifetime " + options);
                dispose(out); dispose(input); PA_DisposeHandle(h);
                balance(label + " dispatcher " + options);
            }
        }
        {
            ARRAY_TEXT a; const uint8_t bytes[] = {'A', 0, 'B'};
            a.appendUTF8String(bytes, 3); CUTF16String got; a.copyUTF16StringAtIndex(&got, 0);
            check(got.size() == 3 && got[1] == 0 && got[2] == 'B', "array UTF8 explicit embedded null length");
            CUTF8String back; a.copyUTF8StringAtIndex(&back, 0);
            check(back.size() == 3 && back[2] == 'B', "array UTF8 return explicit embedded null length");
            C_TEXT scalar; scalar.setUTF8String(bytes, 3); scalar.copyUTF8String(&back);
            check(scalar.getUTF16Length() == 3 && back.size() == 3 && back[2] == 'B',
                  "scalar UTF8 explicit embedded null length");
            std::string narrow("A\0B", 3); CUTF16String converted;
            convertFromString(narrow, converted);
            check(converted.size() == 3 && converted[2] == 'B', "JSON conversion explicit embedded null length");
        }
        arrayCases<ARRAY_TEXT>(eVK_ArrayUnicode, "text array");
        arrayCases<ARRAY_BOOLEAN>(eVK_ArrayBoolean, "boolean array");
        arrayCases<ARRAY_INTEGER>(eVK_ArrayInteger, "integer array");
        arrayCases<ARRAY_LONGINT>(eVK_ArrayLongint, "longint array");
        arrayCases<ARRAY_REAL>(eVK_ArrayReal, "real array");
        arrayCases<ARRAY_DATE>(eVK_ArrayDate, "date array");
        arrayCases<ARRAY_TIME>(eVK_ArrayTime, "time array");
        {
            CBytes b; const uint8_t data[] = {'A', 'B', 'C'};
            b.setBytes(data, 3); b.setBytes(nullptr, 0);
            check(b.getBytesLength() == 0 && !b.getBytesPtr(), "BLOB null reset clears old bytes");
            b.setBytes(data, 3);
            PA_Handle h = nullptr; uint8_t* args[] = {reinterpret_cast<uint8_t*>(&h)};
            b.fromParamAtIndex(args, 1);
            check(!b.getBytesLength(), "BLOB null input clears old bytes");
            b.setBytes(data, 3); C_TEXT encoded;
            encoded.setUTF8String(reinterpret_cast<const uint8_t*>("QQ=="), 4);
            b.fromB64Text(&encoded); b.fromB64Text(&encoded);
            check(b.getBytesLength() == 1 && *b.getBytesPtr() == 'A', "Base64 reuse replaces prior bytes");
            h = PA_NewHandle(3); memcpy(*h, "OLD", 3); PA_Handle old = h;
            failHandle = true; bool reported = false;
            try { b.toParamAtIndex(args, 1); } catch (const std::runtime_error&) { reported = true; }
            failHandle = false;
            check(reported && h == old && handles.count(h), "BLOB failed replacement reports and preserves old owner");
            // Baseline leaves a dangling slot; never dereference it.
            if (!handles.count(h)) h = nullptr;
            b.toParamAtIndex(args, 1);
            check(PA_GetHandleSize(h) == 1 && **h == 'A', "BLOB successful replacement transfers handle");
            PA_DisposeHandle(h);
            b.setBytes(data, 3); uint32_t wanted = 2;
            const uint8_t* slice = b.getBytesPtrForSize(&wanted);
            check(wanted == 2 && slice && slice[0] == 'A' && slice[1] == 'B',
                  "BLOB cursor bounded read");
            C_TEXT hex; b.toHexText(&hex); b.fromHexText(&hex);
            check(b.getBytesLength() == 3 && *b.getBytesPtr() == 'A', "BLOB hexadecimal owner-independent roundtrip");
            wanted = 3; slice = b.getBytesPtrForSize(&wanted);
            check(wanted == 3 && slice && slice[0] == 'A', "BLOB decoded replacement resets cursor");
        }
        balance("BLOB helpers");
        {
            PA_Unistring out = {}; dispatch(1, {}, out);
            check(Text(out.fString, out.fLength).find(text("synthetic-ocr")) != Text::npos,
                  "exported selector-1 info JSON");
            dispose(out);
        }
        balance("info");
        {
            fixture::mode = 9;
            PA_Handle h = nullptr; PA_Unistring options = make(text("{}").c_str()), out = {};
            dispatch(2, {&h, &options}, out);
            check(Text(out.fString, out.fLength) == text("{\"results\":[]}") &&
                  Text(options.fString, options.fLength) == text("{}"),
                  "exported initialization failure preserves empty result and unchanged options");
            dispose(options); dispose(out); fixture::mode = 0;
        }
        balance("initialization failure");
        for (int kind : {0, 1, 2, 3}) {
            resultKind = kind;
            {
                C_PICTURE p; p.setBytes(reinterpret_cast<const uint8_t*>("IMG"), 3);
                PA_Picture out = p.createGrayScale(); PA_DisposePicture(out);
                out = p.createThumbnail(3, 4); PA_DisposePicture(out);
                unsigned int w = 0, h = 0; p.getSize(&w, &h);
                check(w == 3 && h == 4, "picture size synthetic command result-" + std::to_string(kind));
                CUTF8String path(reinterpret_cast<const uint8_t*>("synthetic-not-a-file"));
                p.fromFileAtPath(&path);
                check(p.getPicture() && !invalidDisposals,
                      "picture file-command stub avoids double string disposal result-" + std::to_string(kind));
                PA_Picture returned = nullptr; p.setReturn(reinterpret_cast<sLONG_PTR*>(&returned));
                check(pictures.count(returned) && pictures[returned] >= 2,
                      "picture return independently retained result-" + std::to_string(kind));
                PA_DisposePicture(returned);
            }
            balance("picture commands result-" + std::to_string(kind));
        }
        resultKind = 0;
        {
            C_PICTURE p;
            for (int command : {988, 457, 679, 678}) {
                failCommand = command; bool reported = false;
                try {
                    if (command == 988) PA_DisposePicture(p.createGrayScale());
                    if (command == 679) PA_DisposePicture(p.createThumbnail(3, 4));
                    if (command == 457) { unsigned int w, h; p.getSize(&w, &h); }
                    if (command == 678) { CUTF8String path(reinterpret_cast<const uint8_t*>("stub")); p.fromFileAtPath(&path); }
                } catch (const std::runtime_error& e) { reported = std::string(e.what()).find("-1") != std::string::npos; }
                check(reported && invalidResults == 0,
                      "failed picture command stops before unspecified result adoption " + std::to_string(command));
                failCommand = 0;
            }
        }
        balance("failed picture commands");
        {
            C_PICTURE p; PA_Picture old = p.getPicture(); failPicture = true; bool reported = false;
            try { p.setBytes(reinterpret_cast<const uint8_t*>("IMG"), 3); }
            catch (const std::runtime_error& e) { reported = std::string(e.what()).find("-1") != std::string::npos; }
            failPicture = false;
            check(reported && p.getPicture() == old && pictures.count(old),
                  "picture creation error precedes invalid output adoption");
        }
        balance("failed picture creation");
        pictureBytesFailure(false);
        {
            C_POINTER p; PointerBlock pointer = {}; pointer.fClass = 1; pointer.fScope = 0;
            pointer.uValue.fVariable.fTag = 123; pointer.uValue.fVariable.fIndice = 4;
            uint8_t* args[] = {reinterpret_cast<uint8_t*>(&pointer)};
            p.fromParamAtIndex(args, 1); PA_Variable expected = {}, got = {};
            PA_SetVariableOrFieldReference(&expected, &pointer);
            p.getVariable(&got);
            check(!memcmp(&got, &expected, sizeof(got)) && pointerReads == 0,
                  "pointer reference uses pointer metadata without owned value extraction");
        }
        balance("pointer helper");
        {
            C_INTEGER i; i.setShortValue(7); short out = 0; i.setReturn(reinterpret_cast<sLONG_PTR*>(&out));
            check(out == 7, "integer scalar value control");
            C_LONGINT l; l.setIntValue(8); PA_long32 n = 0; l.setReturn(reinterpret_cast<sLONG_PTR*>(&n));
            check(n == 8, "longint scalar value control");
            C_REAL r; r.setDoubleValue(1.5); double d = 0; double* ptr = &d;
            r.setReturn(reinterpret_cast<sLONG_PTR*>(&ptr)); check(d == 1.5, "real scalar value control");
            C_DATE date; date.setYearMonthDay(2026, 11, 12); PA_Date dt = {}; PA_Date* dp = &dt;
            date.setReturn(reinterpret_cast<sLONG_PTR*>(&dp)); check(dt.fYear == 2026, "date scalar value control");
            C_TIME time; time.setSeconds(9); uint32_t seconds = 0;
            time.setReturn(reinterpret_cast<sLONG_PTR*>(&seconds)); check(seconds == 9, "time scalar value control");
        }
        std::cout << "checks=" << checks << " failures=" << failures << "\n";
        return failures ? 1 : 0;
    }
}
