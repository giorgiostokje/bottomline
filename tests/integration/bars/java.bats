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

@test "java: renders Mockito when mockito-core in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.mockito</groupId><artifactId>mockito-core</artifactId><version>5.8.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Mockito"* ]]
}

@test "java: renders Mockito when mockito-junit-jupiter in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.mockito</groupId><artifactId>mockito-junit-jupiter</artifactId><version>5.8.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Mockito"* ]]
}

@test "java: renders Mockito from build.gradle" {
  printf "dependencies { testImplementation 'org.mockito:mockito-core:5.8.0' }\n" > "$FAKE_PROJ/build.gradle"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Mockito"* ]]
}

@test "java: Mockito shown alongside JUnit 5" {
  printf '<project><dependencies><dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><version>5.10.0</version></dependency><dependency><groupId>org.mockito</groupId><artifactId>mockito-core</artifactId><version>5.8.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"JUnit 5"* ]]
  [[ "$BAR_OUTPUT" == *"Mockito"* ]]
}

@test "java: renders Hibernate when hibernate-core in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.hibernate</groupId><artifactId>hibernate-core</artifactId><version>6.4.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Hibernate"* ]]
}

@test "java: renders Hibernate when spring-boot-starter-data-jpa in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Hibernate"* ]]
}

@test "java: renders Hibernate from build.gradle" {
  printf "dependencies { implementation 'org.hibernate:hibernate-core:6.4.0.Final' }\n" > "$FAKE_PROJ/build.gradle"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Hibernate"* ]]
}

@test "java: renders Flyway when flyway-core in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId><version>10.4.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flyway"* ]]
}

@test "java: renders Flyway from build.gradle" {
  printf "dependencies { implementation 'org.flywaydb:flyway-core:10.4.0' }\n" > "$FAKE_PROJ/build.gradle"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flyway"* ]]
}

@test "java: renders Liquibase when liquibase-core in pom.xml" {
  printf '<project><dependencies><dependency><groupId>org.liquibase</groupId><artifactId>liquibase-core</artifactId><version>4.25.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Liquibase"* ]]
}

@test "java: renders Liquibase from build.gradle" {
  printf "dependencies { implementation 'org.liquibase:liquibase-core:4.25.0' }\n" > "$FAKE_PROJ/build.gradle"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Liquibase"* ]]
}

@test "java: Liquibase suppressed when Flyway also present" {
  printf '<project><dependencies><dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId><version>10.4.0</version></dependency><dependency><groupId>org.liquibase</groupId><artifactId>liquibase-core</artifactId><version>4.25.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flyway"* ]]
  [[ "$BAR_OUTPUT" != *"Liquibase"* ]]
}

@test "java: Hibernate appears before Flyway in slot ordering" {
  printf '<project><dependencies><dependency><groupId>org.hibernate</groupId><artifactId>hibernate-core</artifactId><version>6.4.0</version></dependency><dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId><version>10.4.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  hib_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Hibernate' | head -1 | cut -d: -f1)
  fly_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Flyway' | head -1 | cut -d: -f1)
  [[ -n "$hib_pos" ]] && [[ -n "$fly_pos" ]] && [[ "$hib_pos" -lt "$fly_pos" ]]
}

@test "java: renders Flyway when present without Liquibase" {
  printf '<project><dependencies><dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId><version>10.4.0</version></dependency></dependencies></project>\n' > "$FAKE_PROJ/pom.xml"
  bar_run java "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flyway"* ]]
  [[ "$BAR_OUTPUT" != *"Liquibase"* ]]
}
