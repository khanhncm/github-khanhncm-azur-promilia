$pipeline = @("build-client", "patch-client", "run-client")

foreach ($stage in $pipeline) {
    Write-Host ">> controller.ps1 $stage" -ForegroundColor Cyan
    & "$PSScriptRoot\controller.ps1" $stage
    
    if (-not $? -or $LASTEXITCODE -ne 0) {
        Write-Host "$stage failed with code $LASTEXITCODE, stopping." -ForegroundColor Magenta
        exit $LASTEXITCODE
    }
}
