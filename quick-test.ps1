Set-Alias -Name zig -Value ".\zig\zig-x86_64-windows-0.16.0\zig.exe"
    Write-Host "Verbose output switch was passed!"

(Get-Command zig).Definition

$target = "F:\zenlesszz\zig-x86_64-windows-0.16.0"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

$userPath