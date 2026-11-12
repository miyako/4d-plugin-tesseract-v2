#ifndef OWNERSHIP_JSON_BOUNDARY_H
#define OWNERSHIP_JSON_BOUNDARY_H
#include <map>
#include <vector>
#include <string>
#include <stdexcept>
#define JSONCPP_STRING std::string

namespace Json {
using ArrayIndex = unsigned int;
enum ValueType { nullValue, intValue, uintValue, realValue, stringValue,
                 booleanValue, arrayValue, objectValue };
class Value {
    ValueType type = nullValue;
    std::string scalar;
    std::map<std::string, Value> fields;
    std::vector<Value> items;
    static std::string quote(const std::string& s) {
        std::string out = "\"";
        for (char c : s) {
            if (c == '"' || c == '\\') out += '\\';
            out += c;
        }
        return out + "\"";
    }
public:
    class const_iterator {
        std::map<std::string, Value>::const_iterator it;
    public:
        explicit const_iterator(std::map<std::string, Value>::const_iterator i) : it(i) {}
        const Value* operator->() const { return &it->second; }
        const_iterator& operator++() { ++it; return *this; }
        const_iterator operator++(int) { const_iterator old = *this; ++it; return old; }
        bool operator!=(const const_iterator& other) const { return it != other.it; }
        std::string name() const { return it->first; }
    };
    Value(ValueType t = nullValue) : type(t) {}
    Value(const char* s) : type(stringValue), scalar(s) {}
    Value(const std::string& s) : type(stringValue), scalar(s) {}
    Value(int v) : type(intValue), scalar(std::to_string(v)) {}
    Value(float v) : type(realValue), scalar(std::to_string(v)) {}
    Value(bool v) : type(booleanValue), scalar(v ? "true" : "false") {}
    Value& operator[](const char* key) { type = objectValue; return fields[key]; }
    Value& operator[](int i) { return (*this)[static_cast<ArrayIndex>(i)]; }
    Value& operator[](ArrayIndex i) {
        type = arrayValue;
        if (items.size() <= i) items.resize(i + 1);
        return items[i];
    }
    bool isArray() const { return type == arrayValue; }
    bool isObject() const { return type == objectValue; }
    std::string asString() const {
        if (type != stringValue) throw std::runtime_error("synthetic option type mismatch");
        return scalar;
    }
    int asInt() const { return std::stoi(scalar); }
    unsigned int asUInt() const { return static_cast<unsigned int>(asInt()); }
    bool asBool() const { return scalar == "true"; }
    const_iterator begin() const { return const_iterator(fields.begin()); }
    const_iterator end() const { return const_iterator(fields.end()); }
    std::string dump() const {
        if (type == stringValue) return quote(scalar);
        if (type == nullValue) return "null";
        if (type != arrayValue && type != objectValue) return scalar;
        std::string out = type == arrayValue ? "[" : "{";
        bool first = true;
        if (type == arrayValue) for (const auto& v : items) {
            if (!first) out += ",";
            first = false; out += v.dump();
        }
        else for (const auto& v : fields) {
            if (!first) out += ",";
            first = false; out += quote(v.first) + ":" + v.second.dump();
        }
        return out + (type == arrayValue ? "]" : "}");
    }
};
class StyledWriter { public: std::string write(const Value& v) { return v.dump(); } };
class CharReader {
public:
    bool parse(const char* begin, const char* end, Value* v, std::string*) {
        const std::string s(begin, end);
        *v = objectValue;
        // Only these literal in-memory test options are accepted.
        if (s == "{}") return true;
        if (s == "{\"osd\":true}") { (*v)["osd"] = true; return true; }
        if (s == "{\"getWord\":true}") { (*v)["getWord"] = true; return true; }
        if (s == "{\"getComponentImages\":true}") { (*v)["getComponentImages"] = true; return true; }
        if (s == "{\"format\":\".tiff\"}") { (*v)["format"] = ".tiff"; return true; }
        if (s == "invalid") return false;
        throw std::runtime_error("unexpected synthetic JSON input");
    }
};
class CharReaderBuilder { public: CharReader* newCharReader() { return new CharReader; } };
}
#endif
