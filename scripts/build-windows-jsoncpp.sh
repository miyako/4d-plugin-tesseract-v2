#!/usr/bin/env bash
# Build jsoncpp 1.9.4 as a static x64 /MT library for the Windows build.
#
# include/json is jsoncpp 1.9.4 (identical to the upstream tag), but the old
# lib/Windows64/jsoncpp.lib was a 1.8.x build: it lacks
# Value::operator=(Value&&) and the const ValueIteratorBase::deref(), so the
# plugin failed to link (LNK2001), and mixing the two versions is an ODR risk.
#
# Usage (Git Bash on the windows-latest runner, MSVC + CMake on PATH):
#   scripts/build-windows-jsoncpp.sh <output .lib> [platform toolset, default v143]
set -euo pipefail

OUT_ARG="${1:?usage: $0 <output .lib> [toolset]}"
TOOLSET="${2:-v143}"
VER=1.9.4
SHA256=e34a628a8142643b976c7233ef381457efad79468c67cb1ae0b83a33d7493999

mkdir -p "$(dirname "$OUT_ARG")"
OUT="$(cd "$(dirname "$OUT_ARG")" && pwd)/$(basename "$OUT_ARG")"
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/jsoncpp-build"
mkdir -p "$WORK"
cd "$WORK"

if ! echo "$SHA256  jsoncpp-$VER.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
  curl -fsSL --retry 5 --retry-delay 5 -o "jsoncpp-$VER.tar.gz" \
    "https://github.com/open-source-parsers/jsoncpp/archive/refs/tags/$VER.tar.gz"
  echo "$SHA256  jsoncpp-$VER.tar.gz" | sha256sum -c -
fi
rm -rf "jsoncpp-$VER" build
tar xzf "jsoncpp-$VER.tar.gz"

# Same toolset as the plugin (an older linker can't read newer objects),
# static CRT (/MT) like the vcxproj Release|x64 config, no /GL.
cmake -S "jsoncpp-$VER" -B build -A x64 -T "$TOOLSET" \
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_OBJECT_LIBS=OFF \
  -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF \
  -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF -DJSONCPP_WITH_CMAKE_PACKAGE=OFF
cmake --build build --config Release --target jsoncpp_static

LIB="$(find build -iname 'jsoncpp*.lib' -ipath '*release*' | head -1)"
[ -n "$LIB" ] || { echo "::error::jsoncpp static library not found"; find build -iname '*.lib'; exit 1; }
cp "$LIB" "$OUT"

# The two symbols the 1.8.x library lacked must be present now.
for sym in '??4Value@Json@@QEAAAEAV01@$$QEAV01@@Z' '?deref@ValueIteratorBase@Json@@IEBAAEBVValue@2@XZ'; do
  LC_ALL=C grep -q -a -F "$sym" "$OUT" || { echo "::error::$sym missing from $OUT"; exit 1; }
done
LC_ALL=C grep -q -a -F 'RuntimeLibrary=MT_StaticRelease' "$OUT" || { echo "::error::$OUT is not built with /MT"; exit 1; }
echo "built $OUT (jsoncpp $VER, $TOOLSET, /MT)"
