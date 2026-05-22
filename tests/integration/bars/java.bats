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

@test "java: renders JUnit 5 when in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><version>5.10.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"JUnit 5"* ]]
}

@test "java: JUnit 5 suppresses JUnit 4 when both present" {
  printf '<project><dependencies><dependency><groupId>junit</groupId><artifactId>junit</artifactId><version>4.13.2</version></dependency><dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><version>5.10.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"JUnit 5"* ]]
  [[ "$BAR_OUTPUT" != *"JUnit 4"* ]]
}

@test "java: renders TestNG when in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.testng</groupId><artifactId>testng</artifactId><version>7.8.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TestNG"* ]]
}

@test "java: renders Lombok when in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId><version>1.18.30</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Lombok"* ]]
}

@test "java: renders Checkstyle when in pom.xml" {
  printf '<project><build><plugins><plugin><artifactId>maven-checkstyle-plugin</artifactId></plugin></plugins></build></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Checkstyle"* ]]
}

@test "java: renders SpotBugs when in pom.xml" {
  printf '<project><build><plugins><plugin><artifactId>spotbugs-maven-plugin</artifactId></plugin></plugins></build></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SpotBugs"* ]]
}
