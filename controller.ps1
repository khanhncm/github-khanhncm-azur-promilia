
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("build-client", "build-server")]
    [string]$Action
)

$env:Path += ";F:\unity-mod\azur-promilia\github-khanhncm-azur-promilia\zig\zig-x86_64-windows-0.16.0"
(Get-Command zig).Definition
zig version

switch ($Action) {
    "build-client" {
        Push-Location -Path .\client\evergreen
        try {
            zig build -Doptimize=ReleaseSmall
        }
        finally {
            Pop-Location
        }
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
8   }
    default {
        Write-Host "Unknown action: '$Action'" -ForegroundColor Red
    }
}
