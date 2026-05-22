#!/usr/bin/env bats
# Integration tests for the dotnet bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "dotnet: exits silently when no .NET files" {
  bar_run dotnet "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "dotnet: renders .NET from global.json" {
  printf '{"sdk":{"version":"8.0.100"}}\n' > "$FAKE_PROJ/global.json"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *".NET"* ]]
  [[ "$BAR_OUTPUT" == *"8.0.100"* ]]
}

@test "dotnet: renders .NET from Directory.Build.props" {
  printf '<Project></Project>\n' > "$FAKE_PROJ/Directory.Build.props"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *".NET"* ]]
}

@test "dotnet: renders target framework from .csproj" {
  printf '{"sdk":{"version":"8.0.100"}}\n' > "$FAKE_PROJ/global.json"
  cat > "$FAKE_PROJ/MyApp.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"net8.0"* ]]
}

@test "dotnet: renders .NET from .csproj without global.json" {
  cat > "$FAKE_PROJ/MyApp.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *".NET"* ]]
  [[ "$BAR_OUTPUT" == *"net8.0"* ]]
}

@test "dotnet: renders .NET from .sln file" {
  printf 'Microsoft Visual Studio Solution File, Format Version 12.00\n' \
    > "$FAKE_PROJ/MySolution.sln"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *".NET"* ]]
}

@test "dotnet: renders ASP.NET Core when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.AspNetCore.App"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ASP.NET"* ]]
}

@test "dotnet: renders xUnit when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="xunit" Version="2.6.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"xUnit"* ]]
}

@test "dotnet: renders NUnit when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="NUnit" Version="4.0.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"NUnit"* ]]
}

@test "dotnet: renders EF Core when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"EF"* ]]
}

@test "dotnet: renders StyleCop when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="StyleCop.Analyzers" Version="1.2.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"StyleCop"* ]]
}
