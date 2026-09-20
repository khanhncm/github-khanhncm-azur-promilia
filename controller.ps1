
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("build-client", "print-something")]
    [string]$Action
)

switch ($Action) {
    "build-client" {
        Set-Alias -Name zig -Value ".\zig\zig-x86_64-windows-0.16.0\zig.exe"
        (Get-Command zig).Definition
        zig version
        zig build -Doptimize=ReleaseSmall
    }
    "print-something" {
        Write-Host "Verbose output switch was passed!"
    }
    default {
        Write-Host "Unknown action: '$Action'" -ForegroundColor Red
    }
}
