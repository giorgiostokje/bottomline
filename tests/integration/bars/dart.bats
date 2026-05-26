#!/usr/bin/env bats
# Integration tests for the dart bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "dart: exits silently when no pubspec.yaml" {
  bar_run dart "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "dart: renders Dart and package name from pubspec.yaml" {
  cat > "$FAKE_PROJ/pubspec.yaml" <<'EOF'
name: my_app
description: A sample app.
environment:
  sdk: '>=3.0.0 <4.0.0'
EOF
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dart"* ]]
  [[ "$BAR_OUTPUT" == *"my_app"* ]]
}

@test "dart: renders SDK version from environment.sdk" {
  cat > "$FAKE_PROJ/pubspec.yaml" <<'EOF'
name: my_app
environment:
  sdk: '>=3.2.0 <4.0.0'
EOF
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"3.2.0"* ]]
}

@test "dart: labels SDK constraint version with >= prefix not v prefix" {
  cat > "$FAKE_PROJ/pubspec.yaml" <<'EOF'
name: my_app
environment:
  sdk: '>=3.4.0 <4.0.0'
EOF
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *">=3.4.0"* ]]
}

@test "dart: shows Flutter segment when flutter SDK dependency present" {
  cat > "$FAKE_PROJ/pubspec.yaml" <<'EOF'
name: my_flutter_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
EOF
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dart"* ]]
  [[ "$BAR_OUTPUT" == *"Flutter"* ]]
}

@test "dart: no Flutter segment for plain Dart project" {
  cat > "$FAKE_PROJ/pubspec.yaml" <<'EOF'
name: my_dart_lib
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  http: ^1.0.0
EOF
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dart"* ]]
  [[ "$BAR_OUTPUT" != *"Flutter"* ]]
}

@test "dart: renders flutter_test when present in pubspec" {
  printf 'name: x\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"flutter_test"* ]]
}

@test "dart: flutter_test suppresses test package when both present" {
  printf 'name: x\ndev_dependencies:\n  test: ^1.24.0\n  flutter_test:\n    sdk: flutter\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"flutter_test"* ]]
  # Confirm the standalone "test" segment is NOT emitted by checking the segment
  # appears exactly once (as "flutter_test"), not twice.
  test_count=$(grep -o "test" <<< "$BAR_OUTPUT" | wc -l)
  [ "$test_count" -eq 1 ]
}

@test "dart: renders riverpod when present" {
  printf 'name: x\ndependencies:\n  flutter_riverpod: ^2.5.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Riverpod"* ]]
}

@test "dart: renders bloc when present" {
  printf 'name: x\ndependencies:\n  flutter_bloc: ^8.1.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"BLoC"* ]]
}

@test "dart: renders dio when present" {
  printf 'name: x\ndependencies:\n  dio: ^5.4.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dio"* ]]
}

@test "dart: renders very_good_analysis when present" {
  printf 'name: x\ndev_dependencies:\n  very_good_analysis: ^5.0.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"very_good_analysis"* ]]
}

@test "dart: renders go_router when present" {
  printf 'name: x\ndependencies:\n  go_router: ^13.0.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"go_router"* ]]
}

@test "dart: renders get_it when present" {
  printf 'name: x\ndependencies:\n  get_it: ^7.6.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"get_it"* ]]
}

@test "dart: renders Mocktail when present" {
  printf 'name: x\ndev_dependencies:\n  mocktail: ^1.0.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Mocktail"* ]]
}

@test "dart: Mocktail shown alongside flutter_test" {
  printf 'name: x\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n  mocktail: ^1.0.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"flutter_test"* ]]
  [[ "$BAR_OUTPUT" == *"Mocktail"* ]]
}

@test "dart: renders Freezed when freezed_annotation present" {
  printf 'name: x\ndependencies:\n  freezed_annotation: ^2.4.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Freezed"* ]]
}

@test "dart: renders Freezed when freezed dev dep present" {
  printf 'name: x\ndev_dependencies:\n  freezed: ^2.5.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Freezed"* ]]
}

@test "dart: renders Drift when present" {
  printf 'name: x\ndependencies:\n  drift: ^2.14.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Drift"* ]]
}

@test "dart: Drift appears after Freezed in output" {
  printf 'name: x\ndependencies:\n  freezed_annotation: ^2.4.0\n  drift: ^2.14.0\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  freezed_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Freezed' | head -1 | cut -d: -f1)
  drift_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Drift' | head -1 | cut -d: -f1)
  [ "$freezed_pos" -lt "$drift_pos" ]
}

@test "dart: slot 4 add-ons appear before slot 5 testing" {
  printf 'name: x\ndependencies:\n  dio: ^5.4.0\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n' > "$FAKE_PROJ/pubspec.yaml"
  bar_run dart "$FAKE_PROJ"
  dio_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Dio' | head -1 | cut -d: -f1)
  test_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'flutter_test' | head -1 | cut -d: -f1)
  [ "$dio_pos" -lt "$test_pos" ]
}
