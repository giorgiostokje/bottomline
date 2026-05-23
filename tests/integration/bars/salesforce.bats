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

@test "salesforce: resolves alias to username via legacy ~/.sfdx/alias.json" {
  _minimal_sfdx_json
  local fake_home
  fake_home=$(mktemp -d)
  mkdir -p "$fake_home/.sf" "$fake_home/.sfdx"
  printf '{"target-org":"staging"}\n'                          > "$fake_home/.sf/config.json"
  printf '{"orgs":{"staging":"user@example.com.staging"}}\n'  > "$fake_home/.sfdx/alias.json"
  BAR_OUTPUT_RAW=$(
    HOME="$fake_home" \
    BOTTOMLINE_PROJECT_DIR="$FAKE_PROJ" \
    BOTTOMLINE_LIB="$BOTTOMLINE_ROOT/lib" \
    BOTTOMLINE_ICON_TYPE=none \
    BOTTOMLINE_GRADIENT='"#1a1a1a"' \
    BOTTOMLINE_BAR_COLORS= \
    BOTTOMLINE_BG_R=26 BOTTOMLINE_BG_G=26 BOTTOMLINE_BG_B=26 \
    BOTTOMLINE_SEP='|' \
    BOTTOMLINE_BOLD='' BOTTOMLINE_RESET='' \
    BOTTOMLINE_TEXT_HEX='#e2d5c3' \
    BOTTOMLINE_ACCENT_HEX='#da7756' \
    BOTTOMLINE_WARN_HEX='#f4a261' \
    BOTTOMLINE_DANGER_HEX='#e05a4e' \
    bash "$BOTTOMLINE_ROOT/bars/salesforce.sh"
  )
  BAR_OUTPUT=$(printf '%s' "$BAR_OUTPUT_RAW" | strip_ansi)
  rm -rf "$fake_home"
  [[ "$BAR_OUTPUT" == *"user@example.com.staging"* ]]
}

@test "salesforce: shows username directly when target-org is an email" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"dev@example.com"}\n' > "$FAKE_PROJ/.sf/config.json"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"dev@example.com"* ]]
}

@test "salesforce: PMD detected from .pmdrc config file" {
  _minimal_sfdx_json
  touch "$FAKE_PROJ/.pmdrc"
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PMD"* ]]
}

@test "salesforce: ESLint LWC detected from package.json" {
  _minimal_sfdx_json
  cat > "$FAKE_PROJ/package.json" <<'EOF'
{
  "devDependencies": {
    "@salesforce/eslint-config-lwc": "^3.0.0"
  }
}
EOF
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ESLint"* ]]
  [[ "$BAR_OUTPUT" == *"LWC"* ]]
}

@test "salesforce: neither PMD nor ESLint when absent" {
  _minimal_sfdx_json
  bar_run salesforce "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"PMD"* ]]
  [[ "$BAR_OUTPUT" != *"ESLint"* ]]
}

@test "salesforce: sanitises target_org path separators before legacy ~/.sfdx lookup" {
  _minimal_sfdx_json
  mkdir -p "$FAKE_PROJ/.sf"
  printf '{"target-org":"path/alias"}\n' > "$FAKE_PROJ/.sf/config.json"

  local fake_home; fake_home=$(mktemp -d)
  mkdir -p "$fake_home/.sfdx"
  printf '{"username":"safe@org.example"}\n' > "$fake_home/.sfdx/alias.json"

  local saved_home="$HOME"
  HOME="$fake_home"
  bar_run salesforce "$FAKE_PROJ"
  HOME="$saved_home"
  rm -rf "$fake_home"

  [[ "$BAR_OUTPUT" == *"safe@org.example"* ]]
}
