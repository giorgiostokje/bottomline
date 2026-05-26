#!/usr/bin/env bats
# Integration tests for the swift bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "swift: exits silently when no Package.swift" {
  bar_run swift "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "swift: renders Swift with tools version from Package.swift" {
  printf '// swift-tools-version: 5.9\nimport PackageDescription\n' \
    > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Swift"* ]]
  [[ "$BAR_OUTPUT" == *"5.9"* ]]
}

@test "swift: renders Vapor from Package.resolved" {
  printf '// swift-tools-version: 5.9\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' \
    '{"pins":[{"identity":"vapor","state":{"version":"4.89.0"}}],"version":2}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Vapor"* ]]
  [[ "$BAR_OUTPUT" == *"4.89.0"* ]]
}

@test "swift: no Vapor segment when Package.resolved absent" {
  printf '// swift-tools-version: 5.9\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"Vapor"* ]]
}

@test "swift: renders Hummingbird when in Package.resolved" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '{"pins":[{"identity":"hummingbird","location":"https://github.com/hummingbird-project/hummingbird"}]}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Hummingbird"* ]]
}

@test "swift: renders Alamofire when in Package.resolved" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '{"pins":[{"identity":"alamofire","location":"https://github.com/Alamofire/Alamofire"}]}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Alamofire"* ]]
}

@test "swift: renders Swift Testing when swift-testing dep present" {
  printf 'import PackageDescription\nlet package = Package(name: "x", targets: [.testTarget(name: "xTests", dependencies: [])])\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '{"pins":[{"identity":"swift-testing","location":"https://github.com/apple/swift-testing"}]}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Swift Testing"* ]]
}

@test "swift: renders XCTest when testTarget exists and no Swift Testing" {
  printf 'import PackageDescription\nlet package = Package(name: "x", targets: [.testTarget(name: "xTests", dependencies: [])])\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"XCTest"* ]]
}

@test "swift: Quick suppresses XCTest when both present" {
  printf 'import PackageDescription\nlet package = Package(name: "x", targets: [.testTarget(name: "xTests", dependencies: [])])\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '{"pins":[{"identity":"quick","location":"https://github.com/Quick/Quick"}]}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Quick"* ]]
  [[ "$BAR_OUTPUT" != *"XCTest"* ]]
}

@test "swift: renders SwiftLint when config present" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  printf 'disabled_rules: []\n' > "$FAKE_PROJ/.swiftlint.yml"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SwiftLint"* ]]
}

@test "swift: renders SwiftFormat when config present" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '--indent 4' > "$FAKE_PROJ/.swiftformat"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SwiftFormat"* ]]
}

@test "swift: renders TCA when ComposableArchitecture in Package.swift" {
  printf 'import PackageDescription\nlet package = Package(name: "x", dependencies: [.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")])\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TCA"* ]]
}

@test "swift: no TCA segment when ComposableArchitecture absent" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"TCA"* ]]
}

@test "swift: renders Firebase when firebase-ios-sdk in Package.swift" {
  printf 'import PackageDescription\nlet package = Package(name: "x", dependencies: [.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")])\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Firebase"* ]]
}

@test "swift: renders Firebase when firebase in package URL" {
  printf 'import PackageDescription\nlet package = Package(name: "x", dependencies: [.package(url: "https://github.com/example/firebase-mypackage", from: "1.0.0")])\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Firebase"* ]]
}

@test "swift: no Firebase segment when firebase absent" {
  printf 'import PackageDescription\nlet package = Package(name: "x")\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"Firebase"* ]]
}

@test "swift: TCA and Firebase coexist with Alamofire" {
  printf 'import PackageDescription\nlet package = Package(name: "x", dependencies: [.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"), .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")])\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' '{"pins":[{"identity":"alamofire","location":"https://github.com/Alamofire/Alamofire"}]}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TCA"* ]]
  [[ "$BAR_OUTPUT" == *"Firebase"* ]]
  [[ "$BAR_OUTPUT" == *"Alamofire"* ]]
}
