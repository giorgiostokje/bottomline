#!/usr/bin/env bats
# Integration tests for the java bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "java: exits silently when no build files" {
  bar_run java "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "java: renders Maven when pom.xml exists" {
  printf '<project><modelVersion>4.0.0</modelVersion></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Maven"* ]]
}

@test "java: renders Gradle when build.gradle exists" {
  printf "plugins { id 'java' }\n" > "$FAKE_PROJ/build.gradle"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Gradle"* ]]
}

@test "java: renders Spring Boot from pom.xml" {
  cat > "$FAKE_PROJ/pom.xml" <<'EOF'
<project>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
  </parent>
</project>
EOF
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Spring Boot"* ]]
}
