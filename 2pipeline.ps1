param(
    [Parameter(Position=0)]
    [ValidateSet("client")]
    [string]$Target
)

$pipeline = @()
switch ($Target.ToLower()) {
    "client" { $pipeline = @("build-client", "patch-client", "run-client") }
     default {
        Write-Host "Unknown target: $Target" -ForegroundColor Magenta
        exit 1
    }
}

foreach ($stage in $pipeline) {
    Write-Host ">> controller.ps1 $stage" -ForegroundColor Cyan
    & "$PSScriptRoot\controller.ps1" $stage

    if (-not $? -or $LASTEXITCODE -ne 0) {
        Write-Host "$stage failed, stopping." -ForegroundColor Magenta
        exit 1
    }
}
