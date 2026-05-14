param(
  [switch]$SkipBunInstall,
  [switch]$SkipLink
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
  param([string]$Message)
  Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Warn {
  param([string]$Message)
  Write-Host "WARN  $Message" -ForegroundColor Yellow
}

function Find-Command {
  param([string]$Name)
  return Get-Command $Name -ErrorAction SilentlyContinue
}

function Add-CommonPathEntries {
  $entries = @(
    "$env:USERPROFILE\.bun\bin",
    "$env:APPDATA\npm",
    "$env:ProgramFiles\nodejs",
    "${env:ProgramFiles(x86)}\nodejs"
  )

  foreach ($entry in $entries) {
    if ($entry -and (Test-Path $entry) -and ($env:PATH -notlike "*$entry*")) {
      $env:PATH = "$entry;$env:PATH"
    }
  }
}

function Ensure-NodeAndNpm {
  Add-CommonPathEntries

  if ((Find-Command "node") -and (Find-Command "npm")) {
    Write-Ok "Node and npm are available"
    return
  }

  Write-Warn "Node/npm were not found on PATH"
  $winget = Find-Command "winget"
  if ($winget) {
    Write-Step "Installing Node.js LTS with winget"
    winget install OpenJS.NodeJS.LTS --exact --accept-source-agreements --accept-package-agreements
    Add-CommonPathEntries
  }

  if (-not (Find-Command "node") -or -not (Find-Command "npm")) {
    throw "Node.js LTS and npm are required. Install Node.js LTS, restart PowerShell, then run .\setup.ps1 again."
  }

  Write-Ok "Node and npm are available"
}

function Ensure-Bun {
  Add-CommonPathEntries

  if (Find-Command "bun") {
    Write-Ok "Bun is available"
    return
  }

  if ($SkipBunInstall) {
    throw "Bun was not found and -SkipBunInstall was passed."
  }

  Write-Step "Installing Bun"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex"
  Add-CommonPathEntries

  if (-not (Find-Command "bun")) {
    throw "Bun installed, but was not found on PATH yet. Restart PowerShell, then run .\setup.ps1 again."
  }

  Write-Ok "Bun is available"
}

function Assert-RepoRoot {
  if (-not (Test-Path ".\package.json") -or -not (Test-Path ".\packages\opencode")) {
    throw "Run this script from the tryaksh-cli repository root."
  }
}

Write-Host "Tryaksh CLI setup" -ForegroundColor White
Assert-RepoRoot

Write-Step "Checking required tools"
Ensure-NodeAndNpm
Ensure-Bun

Write-Step "Installing project dependencies"
bun install

if (-not $SkipLink) {
  Write-Step "Linking the tryaksh command"
  npm link --force
}

Write-Step "Verifying Tryaksh CLI"
tryaksh --version

Write-Host ""
Write-Host "Tryaksh CLI is ready." -ForegroundColor Green
Write-Host "Run 'tryaksh' from any project folder to start." -ForegroundColor Green
