
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("build-client", "patch-client", "run-client", "build-server")]
    [string]$Action
)

$env:Path += ";F:\unity-mod\azur-promilia\github-khanhncm-azur-promilia\zig\zig-x86_64-windows-0.16.0"
$ClientPath = ".\client\AzurPromilia_1199241.1273906\AzurPromilia.exe"
$PathResolver = $ExecutionContext.SessionState.Path
$AbsClientPath = $PathResolver.GetUnresolvedProviderPathFromPSPath($ClientPath)
Write-Host "Client: $AbsClientPath" -ForegroundColor Green

switch ($Action) {
    "build-client" {
        Push-Location -Path .\client\evergreen
        try {
            Write-Host "Current Directory: $($PWD.Path)" -ForegroundColor Green
            zig build -Doptimize=ReleaseSmall
        }
        finally {
            Pop-Location
        }
    }
    "patch-client" {
        & {
            $SourcePath      = ".\client\evergreen\zig-out\bin\AzurPromilia.exe"
            $AbsSourcePath   = $PathResolver.GetUnresolvedProviderPathFromPSPath($SourcePath)
            Write-Host "Source: $AbsSourcePath" -ForegroundColor Green
            if (!(Test-Path $SourcePath)) { 
                throw "Not found: $SourcePath - run build-client first" 
            }
            Copy-Item -Path $SourcePath -Destination $AbsClientPath -Force
        }
    }
    "run-client" {
        Start-Process -FilePath $AbsClientPath
    }
    "build-server" {
        Push-Location -Path .\server\zetsa
        try {
            Start-Process zig -ArgumentList "build run-cdnsv -Doptimize=ReleaseSmall" -NoNewWindow
            zig build run-gamesv -Doptimize=ReleaseSmall
        }
        finally {
            Pop-Location
        }
    }
    default {
        (Get-Command zig).Definition
        zig version
        Write-Host "Unknown action: '$Action'" -ForegroundColor Red
    }
}
