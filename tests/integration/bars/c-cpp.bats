#!/usr/bin/env bats
# Integration tests for the c-cpp bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

# Minimal realistic CMakeLists.txt content used across multiple tests.
_write_cmake() {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
set(CMAKE_CXX_STANDARD 20)
find_package(GTest REQUIRED)
enable_testing()
CMAKE
}

@test "c-cpp: exits silently when no signal files present" {
  bar_run c-cpp "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "c-cpp: renders when CMakeLists.txt present" {
  _write_cmake
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"C++"* ]]
}

@test "c-cpp: renders when meson.build present" {
  printf 'project('"'"'myapp'"'"', '"'"'cpp'"'"')\n' > "$FAKE_PROJ/meson.build"
  bar_run c-cpp "$FAKE_PROJ"
  [[ -n "$BAR_OUTPUT" ]]
}

@test "c-cpp: renders when configure.ac present" {
  printf 'AC_INIT([myapp], [1.0])\n' > "$FAKE_PROJ/configure.ac"
  bar_run c-cpp "$FAKE_PROJ"
  [[ -n "$BAR_OUTPUT" ]]
}

@test "c-cpp: shows CMake in output when CMakeLists.txt present" {
  _write_cmake
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"CMake"* ]]
}

@test "c-cpp: shows Meson in output when meson.build present" {
  printf 'project('"'"'myapp'"'"', '"'"'cpp'"'"')\n' > "$FAKE_PROJ/meson.build"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Meson"* ]]
}

@test "c-cpp: shows Autotools in output when configure.ac present" {
  printf 'AC_INIT([myapp], [1.0])\n' > "$FAKE_PROJ/configure.ac"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Autotools"* ]]
}

@test "c-cpp: shows C++ standard when CMAKE_CXX_STANDARD is set" {
  _write_cmake
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"C++20"* ]]
}

@test "c-cpp: shows GoogleTest when detected in CMakeLists.txt" {
  _write_cmake
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"GoogleTest"* ]]
}

@test "c-cpp: shows Catch2 when detected in CMakeLists.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_package(Catch2 REQUIRED)
enable_testing()
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Catch2"* ]]
}

@test "c-cpp: CTest shows when no other test framework found" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
enable_testing()
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"CTest"* ]]
}

@test "c-cpp: CTest does NOT show when GoogleTest is also present" {
  _write_cmake
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"CTest"* ]]
  [[ "$BAR_OUTPUT" == *"GoogleTest"* ]]
}

@test "c-cpp: shows clang-tidy when .clang-tidy file present" {
  _write_cmake
  touch "$FAKE_PROJ/.clang-tidy"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"clang-tidy"* ]]
}

@test "c-cpp: shows clang-format when .clang-format file present" {
  _write_cmake
  touch "$FAKE_PROJ/.clang-format"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"clang-format"* ]]
}

@test "c-cpp: shows cppcheck when referenced in CMakeLists.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_program(CPPCHECK cppcheck)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"cppcheck"* ]]
}

@test "c-cpp: shows vcpkg when vcpkg.json present" {
  _write_cmake
  printf '{"dependencies": []}\n' > "$FAKE_PROJ/vcpkg.json"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"vcpkg"* ]]
}

@test "c-cpp: shows Conan when conanfile.txt present" {
  _write_cmake
  printf '[requires]\n' > "$FAKE_PROJ/conanfile.txt"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Conan"* ]]
}

@test "c-cpp: shows Conan when conanfile.py present" {
  _write_cmake
  printf 'from conan.tools.cmake import CMake\n' > "$FAKE_PROJ/conanfile.py"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Conan"* ]]
}

@test "c-cpp: shows CMake version from cmake_minimum_required" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.28)
project(MyApp CXX)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"3.28"* ]]
}

@test "c-cpp: detects C language from project() declaration" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp C)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"C"* ]]
}

# ── Google Benchmark (slot 5) ────────────────────────────────────────────────

@test "c-cpp: shows Benchmark when detected in CMakeLists.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_package(benchmark REQUIRED)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Benchmark"* ]]
}

@test "c-cpp: shows Benchmark when detected in conanfile.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
CMAKE
  printf '[requires]\nbenchmark/1.6.0\n' > "$FAKE_PROJ/conanfile.txt"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Benchmark"* ]]
}

@test "c-cpp: Benchmark coexists with GoogleTest" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_package(GTest REQUIRED)
find_package(benchmark REQUIRED)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"GoogleTest"* ]]
  [[ "$BAR_OUTPUT" == *"Benchmark"* ]]
}

# ── nlohmann/json (slot 6) ───────────────────────────────────────────────────

@test "c-cpp: shows nlohmann/json when detected in CMakeLists.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_package(nlohmann_json REQUIRED)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"nlohmann/json"* ]]
}

@test "c-cpp: shows nlohmann/json when detected in conanfile.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
CMAKE
  printf '[requires]\nnlohmann_json/3.10.0\n' > "$FAKE_PROJ/conanfile.txt"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"nlohmann/json"* ]]
}

@test "c-cpp: shows nlohmann/json when detected in vcpkg.json" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
CMAKE
  printf '{"dependencies": ["nlohmann-json"]}\n' > "$FAKE_PROJ/vcpkg.json"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"nlohmann/json"* ]]
}

# ── spdlog (slot 6) ──────────────────────────────────────────────────────────

@test "c-cpp: shows spdlog when detected in CMakeLists.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
find_package(spdlog REQUIRED)
CMAKE
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"spdlog"* ]]
}

@test "c-cpp: shows spdlog when detected in conanfile.txt" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
CMAKE
  printf '[requires]\nspdlog/1.10.0\n' > "$FAKE_PROJ/conanfile.txt"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"spdlog"* ]]
}

@test "c-cpp: shows spdlog when detected in vcpkg.json" {
  cat > "$FAKE_PROJ/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(MyApp CXX)
CMAKE
  printf '{"dependencies": ["spdlog"]}\n' > "$FAKE_PROJ/vcpkg.json"
  bar_run c-cpp "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"spdlog"* ]]
}
