$ErrorActionPreference = "Stop"
$originalProgressPreference = $ProgressPreference

$repo = if ($env:HODEXCTL_REPO) { $env:HODEXCTL_REPO } elseif ($env:CODEX_REPO) { $env:CODEX_REPO } else { "stellarlinkco/codex" }
$controllerUrlBase = if ($env:HODEX_CONTROLLER_URL_BASE) { $env:HODEX_CONTROLLER_URL_BASE.TrimEnd('/') } else { "https://raw.githubusercontent.com" }
$stateDir = if ($env:HODEX_STATE_DIR) { $env:HODEX_STATE_DIR } else { $null }
$commandDir = if ($env:HODEX_COMMAND_DIR) { $env:HODEX_COMMAND_DIR } elseif ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { $null }
$controllerUrl = "$controllerUrlBase/$repo/main/scripts/hodexctl/hodexctl.ps1"

$resolvedStateDir = if ($stateDir) {
  $stateDir
} elseif ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA "hodex"
} else {
  Join-Path $HOME "AppData\\Local\\hodex"
}
$resolvedCommandDir = if ($commandDir) { $commandDir } else { Join-Path $resolvedStateDir "commands" }
$resolvedWrapperCmd = Join-Path $resolvedCommandDir "hodexctl.cmd"

function Refresh-SessionPathFromRegistry {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $combined = ""

  if (-not [string]::IsNullOrWhiteSpace($machinePath)) {
    $combined = $machinePath
  }
  if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    if ([string]::IsNullOrWhiteSpace($combined)) {
      $combined = $userPath
    } else {
      $combined = "$combined;$userPath"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($combined)) {
    $env:Path = $combined
  }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$controllerPath = Join-Path $tempRoot "hodexctl.ps1"

try {
  $ProgressPreference = "SilentlyContinue"
  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
  Write-Host "==> 下载 hodexctl 管理脚本"
  Invoke-WebRequest -Uri $controllerUrl -OutFile $controllerPath

  $argumentList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $controllerPath,
    "manager-install",
    "-Yes",
    "-Repo", $repo
  )

  if ($stateDir) {
    $argumentList += @("-StateDir", $stateDir)
  }

  if ($commandDir) {
    $argumentList += @("-CommandDir", $commandDir)
  }

  if ($env:HODEXCTL_NO_PATH_UPDATE -eq "1") {
    $argumentList += "-NoPathUpdate"
  }

  if ($env:GITHUB_TOKEN) {
    $argumentList += @("-GitHubToken", $env:GITHUB_TOKEN)
  }

  $runner = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
  Write-Host "==> 启动 hodexctl 首次安装"
  & $runner @argumentList
  if ($LASTEXITCODE -ne 0) {
    throw "hodexctl manager-install 失败，退出码: $LASTEXITCODE"
  }

  Write-Host "==> 安装完成"
  if ($env:HODEXCTL_NO_PATH_UPDATE -eq "1") {
    Write-Host "==> 已跳过 PATH 写入，可直接运行: $resolvedWrapperCmd status"
  } else {
    if (-not (Get-Command hodexctl -ErrorAction SilentlyContinue)) {
      Refresh-SessionPathFromRegistry
    }
    if (Get-Command hodexctl -ErrorAction SilentlyContinue) {
      Write-Host "==> 当前会话已刷新 PATH，可直接运行: hodexctl status"
    } else {
      $env:Path = "$resolvedCommandDir;$env:Path"
      Write-Host "==> 当前会话已添加命令目录到 PATH，可直接运行: hodexctl status"
    }
  }
} finally {
  $ProgressPreference = $originalProgressPreference
  if (Test-Path $tempRoot) {
    Remove-Item -Recurse -Force $tempRoot
  }
}
