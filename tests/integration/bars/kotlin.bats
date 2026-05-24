#!/usr/bin/env bats
# Integration tests for the kotlin bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

# ── Guard tests ───────────────────────────────────────────────────────────────

@test "kotlin: exits silently when no build.gradle.kts" {
  bar_run kotlin "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "kotlin: exits silently when build.gradle.kts has no kotlin plugin" {
  # Java Gradle project using Kotlin DSL for config only — no kotlin() plugin
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    java
    application
}

dependencies {
    implementation("org.apache.commons:commons-lang3:3.12.0")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

# ── Slot 1: Runtime ───────────────────────────────────────────────────────────

@test "kotlin: renders Kotlin when kotlin plugin present" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    application
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotlin"* ]]
}

@test "kotlin: renders Kotlin version from kotlin(jvm) plugin declaration" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    application
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotlin"* ]]
  [[ "$BAR_OUTPUT" == *"1.9.22"* ]]
}

@test "kotlin: renders Kotlin version from org.jetbrains.kotlin plugin declaration" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    id("org.jetbrains.kotlin.jvm") version "2.0.0"
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotlin"* ]]
  [[ "$BAR_OUTPUT" == *"2.0.0"* ]]
}

@test "kotlin: renders Kotlin without version when version not found" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm")
    application
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotlin"* ]]
}

# ── Slot 2: Build tool ────────────────────────────────────────────────────────

@test "kotlin: always renders Gradle" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Gradle"* ]]
}

@test "kotlin: renders Gradle version from wrapper properties" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}
EOF
  mkdir -p "$FAKE_PROJ/gradle/wrapper"
  cat > "$FAKE_PROJ/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Gradle"* ]]
  [[ "$BAR_OUTPUT" == *"8.5"* ]]
}

# ── Slot 3: Framework ─────────────────────────────────────────────────────────

@test "kotlin: renders Ktor when detected" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    application
}

dependencies {
    implementation("io.ktor:ktor-server-core:2.3.7")
    implementation("io.ktor:ktor-server-netty:2.3.7")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Ktor"* ]]
  [[ "$BAR_OUTPUT" == *"2.3.7"* ]]
}

@test "kotlin: renders Spring Boot when detected" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    id("org.springframework.boot") version "3.2.1"
    id("io.spring.dependency-management") version "1.1.4"
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Spring Boot"* ]]
}

@test "kotlin: Ktor takes priority over Spring Boot when both present" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    id("org.springframework.boot") version "3.2.1"
}

dependencies {
    implementation("io.ktor:ktor-server-core:2.3.7")
    implementation("org.springframework.boot:spring-boot-starter-web")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Ktor"* ]]
  [[ "$BAR_OUTPUT" != *"Spring Boot"* ]]
}

# ── Slot 5: Testing ───────────────────────────────────────────────────────────

@test "kotlin: renders Kotest when detected" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}

dependencies {
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.kotest:kotest-assertions-core:5.8.0")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotest"* ]]
  [[ "$BAR_OUTPUT" == *"5.8.0"* ]]
}

@test "kotlin: renders JUnit 5 when detected (no Kotest)" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"JUnit 5"* ]]
}

@test "kotlin: Kotest suppresses JUnit5 when both present" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}

dependencies {
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotest"* ]]
  [[ "$BAR_OUTPUT" != *"JUnit 5"* ]]
}

@test "kotlin: MockK shows alongside Kotest (different purpose, not suppressed)" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}

dependencies {
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.mockk:mockk:1.13.8")
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Kotest"* ]]
  [[ "$BAR_OUTPUT" == *"MockK"* ]]
}

# ── Slot 6: Tooling ───────────────────────────────────────────────────────────

@test "kotlin: renders Detekt when detected via build.gradle.kts" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Detekt"* ]]
}

@test "kotlin: renders Detekt when detected via config file" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
}
EOF
  touch "$FAKE_PROJ/detekt.yml"
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Detekt"* ]]
}

@test "kotlin: renders ktlint when detected" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ktlint"* ]]
}

@test "kotlin: renders Detekt before ktlint when both present" {
  cat > "$FAKE_PROJ/build.gradle.kts" <<'EOF'
plugins {
    kotlin("jvm") version "1.9.22"
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}
EOF
  bar_run kotlin "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Detekt"* ]]
  [[ "$BAR_OUTPUT" == *"ktlint"* ]]
  # Detekt must appear before ktlint in the output
  detekt_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Detekt' | head -1 | cut -d: -f1)
  ktlint_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'ktlint' | head -1 | cut -d: -f1)
  [[ "$detekt_pos" -lt "$ktlint_pos" ]]
}
