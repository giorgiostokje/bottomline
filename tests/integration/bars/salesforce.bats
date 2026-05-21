#!/usr/bin/env bats
# Integration tests for the salesforce bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

_minimal_sfdx_json() {
  cat > "$FAKE_PROJ/sfdx-project.json" <<'EOF'
{
  "packageDirectories": [{ "path": "force-app", "default": true }],
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "59.0"
}
EOF
}

@test "salesforce: exits silently when no sfdx-project.json" {
  bar_run salesforce "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "salesforce: renders Salesforce label" {
  _minimal_sfdx_json
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Salesforce"* ]]
}

@test "salesforce: shows source API version" {
  _minimal_sfdx_json
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"API"* ]]
  [[ "$BAR_OUTPUT" == *"59.0"* ]]
}

@test "salesforce: shows target org from project .sf/config.json" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"my-dev-org"}\n' > "$FAKE_PROJ/.sf/config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"my-dev-org"* ]]
}

@test "salesforce: shows target org from legacy .sfdx/sfdx-config.json" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sfdx"
  printf '{"defaultusername":"legacy-org"}\n' > "$FAKE_PROJ/.sfdx/sfdx-config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"legacy-org"* ]]
}

@test "salesforce: .sf/config.json takes priority over .sfdx/sfdx-config.json" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"sf-org"}\n' > "$FAKE_PROJ/.sf/config.json"
  mkdir -p "$FAKE_PROJ/.sfdx"
  printf '{"defaultusername":"legacy-org"}\n' > "$FAKE_PROJ/.sfdx/sfdx-config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"sf-org"* ]]
  [[ "$BAR_OUTPUT" != *"legacy-org"* ]]
}

@test "salesforce: shows sandbox indicator for test.salesforce.com" {
  cat > "$FAKE_PROJ/sfdx-project.json" <<'EOF'
{
  "packageDirectories": [{ "path": "force-app", "default": true }],
  "sfdcLoginUrl": "https://test.salesforce.com",
  "sourceApiVersion": "59.0"
}
EOF
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"my-sandbox"}\n' > "$FAKE_PROJ/.sf/config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"sandbox"* ]]
}

@test "salesforce: no sandbox indicator for production login URL" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"my-prod-org"}\n' > "$FAKE_PROJ/.sf/config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"sandbox"* ]]
}

@test "salesforce: no org segment when no config files present" {
  _minimal_sfdx_json
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Salesforce"* ]]
  [[ "$BAR_OUTPUT" != *"my-dev-org"* ]]
}

@test "salesforce: shows namespace when set in project config" {
  cat > "$FAKE_PROJ/sfdx-project.json" <<'EOF'
{
  "packageDirectories": [{ "path": "force-app", "default": true }],
  "namespace": "myns",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "59.0"
}
EOF
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"myns"* ]]
}

@test "salesforce: omits namespace when not set" {
  _minimal_sfdx_json
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"ns:"* ]]
}

@test "salesforce: shows username directly when target-org is an email" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"dev@example.com"}\n' > "$FAKE_PROJ/.sf/config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"dev@example.com"* ]]
}
