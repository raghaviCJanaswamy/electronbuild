<#
  .SYNOPSIS
    Fetches R for Windows from CRAN and creates a "portable-like" tree under r-portable/ by extracting the installer with 7-Zip.
    This is NOT an official "R Portable" from CRAN (CRAN does not publish a portable ZIP). We unpack the NSIS installer non-interactively.

  .REQUIREMENTS
    - PowerShell 5+
    - 7-Zip or p7zip: any of '7z', '7zz', or '7za' available on PATH

  .USAGE
    .\scripts\get-r-portable.ps1                 # attempts latest from CRAN base page
    .\scripts\get-r-portable.ps1 -Version 4.4.1  # fetches from /old/4.4.1/
    .\scripts\get-r-portable.ps1 -Url https://cran.r-project.org/bin/windows/base/old/4.4.1/R-4.4.1-win.exe
    .\scripts\get-r-portable.ps1 -Version 4.4.1 -VerifyChecksum

  .NOTES
    Resulting Rscript(.exe) should land at:
      r-portable\R-Portable\App\R-Portable\bin\Rscript.exe
#>

[CmdletBinding()]
function Ensure-Directory([string]$PathToMake) {
  try {
    $null = [System.IO.Directory]::CreateDirectory($PathToMake)
    if (-not (Test-Path -LiteralPath $PathToMake)) {
      throw "Failed to create directory: $PathToMake"
    }
  } catch {
    throw "Could not create or access directory: $PathToMake. Details: $($_.Exception.Message)"
  }
}

param(
  [string]$Version = "",            # blank = try latest; else use /old/<Version>/
  [string]$OutDir = ".\r-portable",
  [string]$Url = "",                # override full URL to R-<ver>-win.exe
  [switch]$VerifyChecksum           # only for old versions where md5sum file exists
)

function Require-Tool([string[]]$names) {
  foreach ($n in $names) {
    $cmd = Get-Command $n -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd }
  }
  throw "Required tool not found on PATH. Tried: $($names -join ', '). Please install 7-Zip / p7zip and try again."
}

function Get-CranDownloadInfo {
  function Ensure-Directory([string]$PathToMake) {
  try {
    $null = [System.IO.Directory]::CreateDirectory($PathToMake)
    if (-not (Test-Path -LiteralPath $PathToMake)) {
      throw "Failed to create directory: $PathToMake"
    }
  } catch {
    throw "Could not create or access directory: $PathToMake. Details: $($_.Exception.Message)"
  }
}

param([string]$Version)

  if ($Version -and $Version.Trim() -ne "") {
    $baseUrl = "https://cran.r-project.org/bin/windows/base/old/$Version"
    $exeName = "R-$Version-win.exe"
    $md5Url  = "$baseUrl/md5sum.R-$Version.txt"
    $exeUrl  = "$baseUrl/$exeName"
    return [pscustomobject]@{ ExeUrl = $exeUrl; ExeName = $exeName; Md5Url = $md5Url; IsOld = $true }
  } else {
    $basePage = "https://cran.r-project.org/bin/windows/base/"
    try {
      $html = Invoke-WebRequest -Uri $basePage -UseBasicParsing
      $match = ($html.Links | Where-Object { $_.href -match 'R-\d+\.\d+\.\d+-win\.exe$' } | Select-Object -First 1)
      if (-not $match) { throw "Could not find .exe link on CRAN base page." }
      $exeUrl = $match.href
      if ($exeUrl -notmatch '^https?://') {
        $exeUrl = [System.Uri]::new($basePage, $exeUrl).AbsoluteUri
      }
      $exeName = ($exeUrl -split '/')[ -1 ]
      return [pscustomobject]@{ ExeUrl = $exeUrl; ExeName = $exeName; Md5Url = ""; IsOld = $false }
    } catch {
      throw "Failed to determine latest R installer URL from CRAN base page. Specify -Version or -Url. Details: $($_.Exception.Message)"
    }
  }
}

try {
  Ensure-Directory -PathToMake $OutDir
  $sevenZ = Require-Tool @("7z","7zz","7za")

  $info = $null
  if ([string]::IsNullOrWhiteSpace($Url)) {
    $info = Get-CranDownloadInfo -Version $Version
  } else {
    $info = [pscustomobject]@{ ExeUrl = $Url; ExeName = ($Url -split '/')[ -1 ]; Md5Url = ""; IsOld = $false }
  }

  Ensure-Directory -PathToMake $OutDir
    $exePath = Join-Path $OutDir $info.ExeName
  Write-Host "Downloading R installer from $($info.ExeUrl) ..."
  Invoke-WebRequest -Uri $info.ExeUrl -OutFile $exePath

  if ($VerifyChecksum -and $info.IsOld -and $info.Md5Url) {
    Write-Host "Fetching checksum from $($info.Md5Url) ..."
    $md5Txt = Invoke-WebRequest -Uri $info.Md5Url -UseBasicParsing
    $expected = ($md5Txt.Content -split '\s+')[0]
    Write-Host "Expected MD5: $expected"
    $md5 = Get-FileHash -Path $exePath -Algorithm MD5 | Select-Object -ExpandProperty Hash
    if ($md5.ToLower() -ne $expected.ToLower()) {
      throw "MD5 mismatch! expected $expected got $md5"
    } else {
      Write-Host "MD5 OK"
    }
  }

  $extractTo = Join-Path $OutDir "R-Portable"
  if (Test-Path $extractTo) { Remove-Item -Recurse -Force $extractTo }
  New-Item -ItemType Directory -Force -Path $extractTo | Out-Null

  Write-Host "Extracting installer ..."
  & $sevenZ.Source x $exePath "-o$extractTo" -y | Out-Null

  $binCandidate = Get-ChildItem -Path $extractTo -Recurse -Filter "Rscript.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $binCandidate) {
    throw "Could not locate Rscript.exe after extraction. The installer structure may have changed."
  }

  $targetRoot = Join-Path $OutDir "R-Portable\App\R-Portable"
  if (Test-Path $targetRoot) { Remove-Item -Recurse -Force $targetRoot }
  New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

  Write-Host "Moving extracted files into $targetRoot ..."
  Get-ChildItem -Path $extractTo -Force | ForEach-Object {
    Move-Item -Force -Path $_.FullName -Destination $targetRoot
  }

  $finalR = Join-Path $OutDir "R-Portable\App\R-Portable\bin\Rscript.exe"
  if (-not (Test-Path $finalR)) {
    $binCandidate = Get-ChildItem -Path (Join-Path $OutDir "R-Portable") -Recurse -Filter "Rscript.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($binCandidate) {
      $srcRoot = (Get-Item $binCandidate.Directory.FullName).Parent.Parent.FullName
      Copy-Item -Recurse -Force -Path (Join-Path $srcRoot '*') -Destination $targetRoot
    }
  }

  if (Test-Path $finalR) {
    Write-Host "Success. Rscript.exe is at: $finalR"
    Write-Host "This will be bundled and used by Electron."
  } else {
    Write-Warning "Extraction completed, but expected Rscript.exe not found at $finalR"
    Write-Warning "You may need to adjust this script if installer structure has changed."
  }

} catch {
  Write-Error $_
  exit 1
}
