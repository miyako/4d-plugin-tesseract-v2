#ifndef OWNERSHIP_OCR_BOUNDARY_H
#define OWNERSHIP_OCR_BOUNDARY_H

#include "alltypes.h"
#include <string>
#include <vector>
#include <stdexcept>

namespace fixture {
extern std::string text;
extern int mode, calls, images, boxes, iterators, texts;
}
class STRING {
    std::string value;
public:
    STRING(const char* s = "") : value(s) {}
    const char* string() const { return value.c_str(); }
};
template<class T> class GenericVector : public std::vector<T> {
public:
    int size() const { return static_cast<int>(std::vector<T>::size()); }
};
namespace tesseract {
enum OcrEngineMode { OEM_DEFAULT, OEM_COUNT };
enum PageIteratorLevel { RIL_BLOCK, RIL_PARA, RIL_TEXTLINE, RIL_WORD, RIL_SYMBOL };
enum Orientation { ORIENTATION_PAGE_UP };
enum WritingDirection { WRITING_DIRECTION_LEFT_TO_RIGHT };
enum TextlineOrder { TEXTLINE_ORDER_LEFT_TO_RIGHT };
enum PageSegMode { PSM_AUTO_OSD };
inline char* syntheticText() {
    char* s = new char[fixture::text.size() + 1];
    std::copy(fixture::text.begin(), fixture::text.end(), s);
    s[fixture::text.size()] = 0;
    return s;
}
class PageIterator {
public:
    PageIterator() { ++fixture::iterators; }
    virtual ~PageIterator() { --fixture::iterators; }
    void Orientation(tesseract::Orientation* o, WritingDirection* d,
                     TextlineOrder* order, float* skew) {
        *o = ORIENTATION_PAGE_UP; *d = WRITING_DIRECTION_LEFT_TO_RIGHT;
        *order = TEXTLINE_ORDER_LEFT_TO_RIGHT; *skew = 0;
    }
};
class ResultIterator : public PageIterator {
public:
    char* GetUTF8Text(PageIteratorLevel) { return syntheticText(); }
    float Confidence(PageIteratorLevel) { return 95; }
    bool BoundingBox(PageIteratorLevel, int* a, int* b, int* c, int* d) {
        *a = 1; *b = 2; *c = 3; *d = 4; return true;
    }
    bool Next(PageIteratorLevel) { return false; }
};
class TessPDFRenderer {
public:
    TessPDFRenderer(const char*, const char*, bool) {
        throw std::runtime_error("PDF output prohibited");
    }
};
class TessBaseAPI {
public:
    static const char* Version() { return "synthetic-ocr"; }
    void ClearPersistentCache() {}
    int Init(const char* path, const char* language, OcrEngineMode) {
        if (*path || std::string(language) != "eng")
            throw std::runtime_error("external OCR configuration prohibited");
        return fixture::mode == 9 ? 1 : 0;
    }
    void SetPageSegMode(PageSegMode) {}
    bool SetVariable(const char*, const char*) { return true; }
    void GetAvailableLanguagesAsVector(GenericVector<STRING>* v) {
        v->clear(); v->push_back(STRING("eng"));
    }
    void GetLoadedLanguagesAsVector(GenericVector<STRING>* v) {
        v->clear(); v->push_back(STRING("eng"));
    }
    const char* GetDatapath() { return ""; }
    bool ProcessPages(const char*, const char*, int, TessPDFRenderer*) {
        throw std::runtime_error("file OCR prohibited");
    }
    void SetImage(PIX* p) {
        if (!p) throw std::runtime_error("missing synthetic image");
        ++fixture::calls;
    }
    void SetRectangle(int, int, int, int) {}
    int Recognize(void*) { return 0; }
    PageIterator* AnalyseLayout() { return new PageIterator; }
    ResultIterator* GetIterator() { return new ResultIterator; }
    BOXA* GetComponentImages(PageIteratorLevel, bool, void*, void*);
    char* GetUTF8Text(void (*yield)(), size_t) {
        yield(); return syntheticText();
    }
    int MeanTextConf() { return 95; }
    void End() {}
};
class Dict { public: static void GlobalDawgCache() {} };
class SIMDDetect {
public:
    static bool IsAVX512BWAvailable() { return false; }
    static bool IsAVX512FAvailable() { return false; }
    static bool IsAVX2Available() { return false; }
    static bool IsAVXAvailable() { return false; }
    static bool IsSSEAvailable() { return false; }
};
}
#endif
