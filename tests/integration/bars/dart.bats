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
