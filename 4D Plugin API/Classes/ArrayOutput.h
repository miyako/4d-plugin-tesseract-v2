#ifndef FOURD_ARRAY_OUTPUT_H
#define FOURD_ARRAY_OUTPUT_H

#include "4DPluginAPI.h"
#include <limits>
#include <stdexcept>
#include <string>

inline void prepareArrayOutput(PA_Variable* param, PA_VariableKind kind, size_t count)
{
    size_t width = sizeof(PA_Unistring);
    switch (kind) {
        case eVK_ArrayInteger: width = sizeof(short); break;
        case eVK_ArrayLongint: case eVK_ArrayTime: width = sizeof(PA_long32); break;
        case eVK_ArrayReal: width = sizeof(double); break;
        case eVK_ArrayDate: width = sizeof(PA_Date); break;
        case eVK_ArrayBoolean: width = 1; break;
        default: break;
    }
    const size_t limit = static_cast<size_t>(std::numeric_limits<PA_long32>::max());
    if (count > (kind == eVK_ArrayBoolean ? limit - 7 : limit / width))
        throw std::runtime_error("4D array output is too large");
    if (param->fType == eVK_Undefined)
        *param = PA_CreateVariable(kind);
    if (param->fType != kind)
        throw std::runtime_error("Incompatible 4D array output type");
    if (!param->uValue.fArray.fData)
        throw std::runtime_error("Missing 4D array output storage");

    PA_long32 size = count ? static_cast<PA_long32>(count - 1) : 0;
    if (param->uValue.fArray.fNbElements != size)
    {
        PA_Variable resized = *param;
        PA_ResizeArray(&resized, size);
        const PA_ErrorCode error = PA_GetLastError();
        // The SDK updates its local count even when the allocation fails.
        if (error != eER_NoErr)
            throw std::runtime_error("4D array resize failed: " + std::to_string(error));
        *param = resized;
    }
}

inline void requireArrayInputStorage(const PA_Variable& array)
{
    if (!array.uValue.fArray.fData)
        throw std::runtime_error("Missing 4D array input storage");
}

#endif
