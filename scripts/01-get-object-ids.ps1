Write-Host "`nAzure AD Object ID Lookup" -ForegroundColor Cyan

$roles = @(
    @{ Label='SysAdmin'; VarName='sysadmin_object_id' },
    @{ Label='SupportTech'; VarName='support_user_object_id' },
    @{ Label='Auditor'; VarName='auditor_object_id' }
)

foreach ($role in $roles) {

    $upn = Read-Host "Enter UPN for $($role.Label)"
    $objectId = az ad user show --id $upn --query id -o tsv 2>$null

    Write-Host "$($role.VarName) = \"$objectId\""
}
