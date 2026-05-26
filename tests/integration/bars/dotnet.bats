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

# ── Slot 4: Add-ons ──────────────────────────────────────────────────────────

@test "dotnet: renders gRPC when Grpc.AspNetCore in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Grpc.AspNetCore" Version="2.62.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"gRPC"* ]]
}

@test "dotnet: renders SignalR when Microsoft.AspNetCore.SignalR in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.AspNetCore.SignalR" Version="1.1.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SignalR"* ]]
}

@test "dotnet: renders SignalR when Microsoft.AspNetCore.SignalR.Client in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.AspNetCore.SignalR.Client" Version="8.0.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SignalR"* ]]
}

@test "dotnet: no SignalR when only ASP.NET Core without explicit SignalR package" {
  printf '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.AspNetCore.App"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"SignalR"* ]]
}

@test "dotnet: add-ons appear between framework and testing" {
  printf '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Grpc.AspNetCore" Version="2.62.0"/><PackageReference Include="xunit" Version="2.6.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  local grpc_pos xunit_pos asp_pos
  grpc_pos=${BAR_OUTPUT%%gRPC*}
  xunit_pos=${BAR_OUTPUT%%xUnit*}
  asp_pos=${BAR_OUTPUT%%ASP.NET*}
  [[ ${#asp_pos} -lt ${#grpc_pos} ]]
  [[ ${#grpc_pos} -lt ${#xunit_pos} ]]
}

# ── Slot 6: Tooling additions ────────────────────────────────────────────────

@test "dotnet: renders Dapper when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Dapper" Version="2.1.35"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dapper"* ]]
}

@test "dotnet: Dapper appears after EF Core" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0"/><PackageReference Include="Dapper" Version="2.1.35"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  local ef_pos dapper_pos
  ef_pos=${BAR_OUTPUT%%EF*}
  dapper_pos=${BAR_OUTPUT%%Dapper*}
  [[ ${#ef_pos} -lt ${#dapper_pos} ]]
}

@test "dotnet: renders FluentValidation when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="FluentValidation" Version="11.9.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"FluentValidation"* ]]
}

@test "dotnet: renders FluentValidation when FluentValidation.AspNetCore in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="FluentValidation.AspNetCore" Version="11.3.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"FluentValidation"* ]]
}

@test "dotnet: renders MediatR when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="MediatR" Version="12.2.0"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"MediatR"* ]]
}

@test "dotnet: renders Serilog when in csproj" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Serilog" Version="3.1.1"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Serilog"* ]]
}

@test "dotnet: full slot 6 ordering: StyleCop → FluentValidation → MediatR → EF Core → Dapper → Serilog" {
  printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="StyleCop.Analyzers" Version="1.2.0"/><PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0"/><PackageReference Include="Dapper" Version="2.1.35"/><PackageReference Include="FluentValidation" Version="11.9.0"/><PackageReference Include="MediatR" Version="12.2.0"/><PackageReference Include="Serilog" Version="3.1.1"/></ItemGroup></Project>\n' > "$FAKE_PROJ/x.csproj"
  bar_run dotnet "$FAKE_PROJ"
  local sc fv mediatr ef dapper serilog
  sc=${BAR_OUTPUT%%StyleCop*}
  fv=${BAR_OUTPUT%%FluentValidation*}
  mediatr=${BAR_OUTPUT%%MediatR*}
  ef=${BAR_OUTPUT%%EF*}
  dapper=${BAR_OUTPUT%%Dapper*}
  serilog=${BAR_OUTPUT%%Serilog*}
  [[ ${#sc} -lt ${#fv} ]]
  [[ ${#fv} -lt ${#mediatr} ]]
  [[ ${#mediatr} -lt ${#ef} ]]
  [[ ${#ef} -lt ${#dapper} ]]
  [[ ${#dapper} -lt ${#serilog} ]]
}
