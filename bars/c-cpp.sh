#!/usr/bin/env bash
# Bottomline bar: C/C++ ecosystem bar
# Renders for projects with CMakeLists.txt, meson.build, or configure.ac.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init c-cpp "#dce8f0" "#4a8db7" '["#0a1520","#0f2535"]' \
  "$PROJ/CMakeLists.txt" "$PROJ/meson.build" "$PROJ/configure.ac" \
  "$PROJ/conanfile.txt" "$PROJ/conanfile.py" "$PROJ/vcpkg.json"

# Hard guard: exit silently if not a C/C++ project
has_cmake=false has_meson=false has_autotools=false
[[ -f "$PROJ/CMakeLists.txt" ]] && has_cmake=true
[[ -f "$PROJ/meson.build" ]]    && has_meson=true
[[ -f "$PROJ/configure.ac" ]]   && has_autotools=true
$has_cmake || $has_meson || $has_autotools || exit 0

bl_icon_set IC_CPLUSPLUS $'\xee\x98\xa3' '⚙'
bl_icon_set IC_BUILD     $'\xef\x80\x93' '🔨'
bl_icon_set IC_TEST      $'\xef\x81\x80' '🧪'
bl_icon_set IC_LINT      $'\xef\x80\x8c' '✓'
bl_icon_set IC_PKG       $'\xef\x80\xbc' '📦'
bl_icon_set IC_DATA      $'\xef\x87\x80' '{ }'
bl_icon_set IC_LOG       $'\xef\x81\xab' '📋'


# ── Slot 1: Detect language (C, C++, or C/C++) ────────────────────────────────
lang='C/C++'
if $has_cmake; then
  cmake_content=$(cat "$PROJ/CMakeLists.txt" 2>/dev/null)
  has_cxx=false
  has_c=false
  # Check project() call for language tags
  if printf '%s' "$cmake_content" | grep -qiE 'project\([^)]*CXX'; then
    has_cxx=true
  fi
  if printf '%s' "$cmake_content" | grep -qiE 'project\([^)]*[^X]C[ )"]'; then
    has_c=true
  fi
  # Fallback: scan src/ for source file extensions
  if ! $has_cxx && ! $has_c; then
    if find "$PROJ/src" -maxdepth 3 \( -name "*.cpp" -o -name "*.cxx" -o -name "*.cc" \) 2>/dev/null | grep -q .; then
      has_cxx=true
    fi
    if find "$PROJ/src" -maxdepth 3 -name "*.c" 2>/dev/null | grep -q .; then
      has_c=true
    fi
  fi
  if $has_cxx && $has_c; then
    lang='C/C++'
  elif $has_cxx; then
    lang='C++'
  elif $has_c; then
    lang='C'
  fi
fi

# ── Standard version ──────────────────────────────────────────────────────────
lang_standard=''
if $has_cmake; then
  if [[ "$lang" == 'C++' || "$lang" == 'C/C++' ]]; then
    cpp_standard=$(grep -m1 'CMAKE_CXX_STANDARD' "$PROJ/CMakeLists.txt" 2>/dev/null \
      | grep -oE '[0-9]{2,3}' | head -1)
    [[ -n "$cpp_standard" ]] && lang_standard="C++${cpp_standard}"
  fi
  if [[ "$lang" == 'C' ]]; then
    c_standard=$(grep -m1 'CMAKE_C_STANDARD' "$PROJ/CMakeLists.txt" 2>/dev/null \
      | grep -oE '[0-9]{2,3}' | head -1)
    [[ -n "$c_standard" ]] && lang_standard="C${c_standard}"
  fi
fi

# ── Slot 2: Build system ──────────────────────────────────────────────────────
build_system=''
build_version=''
if $has_cmake; then
  build_system='CMake'
  cmake_version=$(grep -m1 -i 'cmake_minimum_required' "$PROJ/CMakeLists.txt" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
elif $has_meson; then
  build_system='Meson'
  meson_version=$(grep -m1 'meson_version' "$PROJ/meson.build" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  build_version="$meson_version"
elif $has_autotools; then
  build_system='Autotools'
fi
# Promote cmake_version to build_version
if [[ "$build_system" == 'CMake' ]]; then
  build_version="${cmake_version:-}"
fi

# ── Slot 4: Package managers (add-ons) ───────────────────────────────────────
has_conan=false
has_vcpkg=false
[[ -f "$PROJ/conanfile.txt" || -f "$PROJ/conanfile.py" ]] && has_conan=true
[[ -f "$PROJ/vcpkg.json" ]]                                && has_vcpkg=true

# ── Slot 5: Testing ───────────────────────────────────────────────────────────
has_gtest=false has_catch2=false has_doctest=false has_boosttest=false has_ctest=false
cmake_for_test="$PROJ/CMakeLists.txt"
meson_for_test="$PROJ/meson.build"

if $has_cmake && [[ -f "$cmake_for_test" ]]; then
  grep -qiE 'gtest|googletest|google_test|GTest' "$cmake_for_test" 2>/dev/null && has_gtest=true
  grep -qiE 'Catch2|catch2'                       "$cmake_for_test" 2>/dev/null && has_catch2=true
  grep -qi  'doctest'                              "$cmake_for_test" 2>/dev/null && has_doctest=true
  grep -qi  'Boost.*unit_test\|boost_unit_test'    "$cmake_for_test" 2>/dev/null && has_boosttest=true
  # CTest is a fallback — show only when no higher-level framework found
  if ! $has_gtest && ! $has_catch2 && ! $has_doctest && ! $has_boosttest; then
    grep -qi 'enable_testing\|include(CTest)' "$cmake_for_test" 2>/dev/null && has_ctest=true
  fi
elif $has_meson && [[ -f "$meson_for_test" ]]; then
  grep -qiE 'gtest|googletest'    "$meson_for_test" 2>/dev/null && has_gtest=true
  grep -qiE 'Catch2|catch2'       "$meson_for_test" 2>/dev/null && has_catch2=true
  grep -qi  'doctest'             "$meson_for_test" 2>/dev/null && has_doctest=true
fi

has_benchmark=false
if $has_cmake && [[ -f "$PROJ/CMakeLists.txt" ]]; then
  grep -qiE 'benchmark' "$PROJ/CMakeLists.txt" 2>/dev/null && has_benchmark=true
fi
if ! $has_benchmark; then
  grep -qi 'benchmark' "$PROJ/conanfile.txt" 2>/dev/null && has_benchmark=true
  grep -qi 'benchmark' "$PROJ/conanfile.py" 2>/dev/null && has_benchmark=true
fi

# ── Slot 6: Tooling ───────────────────────────────────────────────────────────
has_clangtidy=false has_cppcheck=false has_clangformat=false
[[ -f "$PROJ/.clang-tidy" ]] && has_clangtidy=true
if ! $has_clangtidy && $has_cmake && [[ -f "$PROJ/CMakeLists.txt" ]]; then
  grep -qi 'find_program.*CLANG_TIDY\|clang.tidy' "$PROJ/CMakeLists.txt" 2>/dev/null && has_clangtidy=true
fi
if $has_cmake && [[ -f "$PROJ/CMakeLists.txt" ]]; then
  grep -qi 'cppcheck' "$PROJ/CMakeLists.txt" 2>/dev/null && has_cppcheck=true
fi
[[ -f "$PROJ/.cppcheck" ]] && has_cppcheck=true
[[ -f "$PROJ/.clang-format" ]] && has_clangformat=true

has_nlohmann_json=false
has_spdlog=false
if $has_cmake && [[ -f "$PROJ/CMakeLists.txt" ]]; then
  grep -qi 'nlohmann' "$PROJ/CMakeLists.txt" 2>/dev/null && has_nlohmann_json=true
  grep -qi 'spdlog'   "$PROJ/CMakeLists.txt" 2>/dev/null && has_spdlog=true
fi
if ! $has_nlohmann_json; then
  grep -qi 'nlohmann_json' "$PROJ/conanfile.txt" 2>/dev/null && has_nlohmann_json=true
  grep -qi 'nlohmann_json' "$PROJ/conanfile.py" 2>/dev/null && has_nlohmann_json=true
  grep -qi 'nlohmann-json' "$PROJ/vcpkg.json" 2>/dev/null && has_nlohmann_json=true
fi
if ! $has_spdlog; then
  grep -qi 'spdlog' "$PROJ/conanfile.txt" 2>/dev/null && has_spdlog=true
  grep -qi 'spdlog' "$PROJ/conanfile.py" 2>/dev/null && has_spdlog=true
  grep -qi 'spdlog' "$PROJ/vcpkg.json" 2>/dev/null && has_spdlog=true
fi

# ── Slot 1: Runtime ───────────────────────────────────────────────────────────
lang_seg="${FG_ACCENT}${IC_CPLUSPLUS} ${FG_TEXT}${lang}"
[[ -n "$lang_standard" ]] && lang_seg+=" ${N}${FG_ACCENT}${lang_standard}"
add_seg "$lang_seg"

# ── Slot 2: Build system ──────────────────────────────────────────────────────
if [[ -n "$build_system" ]]; then
  build_seg="${FG_ACCENT}${IC_BUILD} ${FG_TEXT}${build_system}"
  [[ -n "$build_version" ]] && build_seg+=" ${N}${FG_ACCENT}${build_version}"
  add_seg "$build_seg"
fi

# ── Slot 4: Package managers ──────────────────────────────────────────────────
$has_conan && bl_seg "$IC_PKG" Conan
$has_vcpkg && bl_seg "$IC_PKG" vcpkg

# ── Slot 5: Testing ───────────────────────────────────────────────────────────
$has_gtest     && bl_seg "$IC_TEST" GoogleTest
$has_catch2    && bl_seg "$IC_TEST" Catch2
$has_doctest   && bl_seg "$IC_TEST" doctest
$has_boosttest && bl_seg "$IC_TEST" Boost.Test
$has_ctest     && bl_seg "$IC_TEST" CTest
$has_benchmark && bl_seg "$IC_TEST" Benchmark

# ── Slot 6: Tooling ───────────────────────────────────────────────────────────
# Static analysis first, then formatter
$has_clangtidy    && bl_seg "$IC_LINT" clang-tidy
$has_cppcheck     && bl_seg "$IC_LINT" cppcheck
$has_clangformat  && bl_seg "$IC_LINT" clang-format
$has_nlohmann_json && bl_seg "$IC_DATA" 'nlohmann/json'
$has_spdlog       && bl_seg "$IC_LOG" spdlog

bl_bar_finish "$_bar_gradient"
