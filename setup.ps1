param(
  [switch]$SkipBunInstall,
  [switch]$SkipLink,
  [switch]$ShowWelcomeAgain
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

function Invoke-NativeCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$FailureMessage
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $FilePath @Arguments 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host $_.Exception.Message
      } else {
        Write-Host $_
      }
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($exitCode -ne 0) {
    throw $FailureMessage
  }
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

function Show-FirstRunWelcome {
  $stateDir = Join-Path $env:USERPROFILE ".local\share\tryaksh"
  $welcomeMarker = Join-Path $stateDir "setup-welcome-shown"

  if ((Test-Path $welcomeMarker) -and (-not $ShowWelcomeAgain)) {
    Write-Host ""
    Write-Host "Tryaksh CLI is ready." -ForegroundColor Green
    Write-Host "Run 'tryaksh' from any project folder to start." -ForegroundColor Green
    return
  }

  if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  }

  Write-Host ""
  Write-Host "================================================================" -ForegroundColor DarkCyan
  Write-Host "                         TRYAKSH CLI" -ForegroundColor White
  Write-Host "================================================================" -ForegroundColor DarkCyan
  Write-Host ""
  Write-Host "Welcome to Tryaksh Innovations." -ForegroundColor White
  Write-Host ""
  Write-Host "You made it this far because you are here to build, learn," -ForegroundColor Gray
  Write-Host "and help shape the revolution we are working toward." -ForegroundColor Gray
  Write-Host ""
  Write-Host "Tryaksh CLI is now ready on this machine." -ForegroundColor Green
  Write-Host "It is built for your ease, your efficiency, and the quality of" -ForegroundColor Gray
  Write-Host "the engineering work you do every day." -ForegroundColor Gray
  Write-Host ""
  Write-Host "You now have AI assistance inside your projects:" -ForegroundColor White
  Write-Host "  tryaksh" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Open any project folder, run the command, and start building." -ForegroundColor Gray
  Write-Host ""
  Write-Host "Welcome aboard. Let us build the future with care." -ForegroundColor White
  Write-Host "================================================================" -ForegroundColor DarkCyan

  Set-Content -Path $welcomeMarker -Value (Get-Date -Format o)
}

Write-Host "Tryaksh CLI setup" -ForegroundColor White
Assert-RepoRoot

Write-Step "Checking required tools"
Ensure-NodeAndNpm
Ensure-Bun

Write-Step "Installing project dependencies"
Invoke-NativeCommand -FilePath "bun" -Arguments @("install") -FailureMessage "bun install failed."

if (-not $SkipLink) {
  Write-Step "Linking the tryaksh command"
  Invoke-NativeCommand -FilePath "npm" -Arguments @("link", "--force") -FailureMessage "npm link failed."
}

Write-Step "Verifying Tryaksh CLI"
Invoke-NativeCommand -FilePath "tryaksh" -Arguments @("--version") -FailureMessage "tryaksh verification failed."

Show-FirstRunWelcome
