param(
    [string]$ResourceGroup = "RG-FileServerLab",
    [string]$VMName = "FS01"
)

Write-Host ""
Write-Host "=== RBAC Lab Validation ===" -ForegroundColor Cyan

# Get FS01 resource ID
$vmId = az vm show -g $ResourceGroup -n $VMName --query id -o tsv
if (-not $vmId) { throw "VM $VMName not found in $ResourceGroup. Confirm Lab 1 is deployed." }
Write-Host "Scope: $vmId"
Write-Host ""

# Query role assignments
$assignments = az role assignment list --scope $vmId `
    --query "[].{role:roleDefinitionName,principal:principalName}" `
    -o json | ConvertFrom-Json

$expected = @(
    @{ Role="Owner"; Label="SysAdmin" },
    @{ Role="Virtual Machine Contributor"; Label="SupportTech" },
    @{ Role="Reader"; Label="Auditor" }
)

$allPass = $true
Write-Host "[ Role Assignment Validation ]"

foreach ($e in $expected) {
    $match = $assignments | Where-Object { $_.role -eq $e.Role }
    if ($match) {
        Write-Host "PASS: $($e.Role) -> $($match.principal)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $($e.Role) not found on $VMName" -ForegroundColor Red
        $allPass = $false
    }
}

Write-Host ""
Write-Host "[ Permission Matrix - FS01 scope only ]"

$matrix = @(
    @{ Action="View VM details";   O="Yes"; VC="Yes"; R="Yes" },
    @{ Action="Start / Stop VM";   O="Yes"; VC="Yes"; R="No"  },
    @{ Action="Connect via RDP";   O="Yes"; VC="Yes"; R="No"  },
    @{ Action="Delete VM";         O="Yes"; VC="No";  R="No"  },
    @{ Action="Manage RBAC roles"; O="Yes"; VC="No";  R="No"  }
)

Write-Host ("{0,-26} {1,-8} {2,-20} {3}" -f "Action","Owner","VM Contributor","Reader")
foreach ($row in $matrix) {
    Write-Host ("{0,-26} {1,-8} {2,-20} {3}" -f $row.Action,$row.O,$row.VC,$row.R)
}

# Export report
$report = "RBAC Lab Validation Report`nGenerated: $(Get-Date)`nVM Resource ID: $vmId`n`n"
$report += ($assignments | Format-Table -AutoSize | Out-String)
$report += "`nOverall: " + $(if ($allPass) { "ALL PASS" } else { "FAILURES DETECTED" })

Out-File -FilePath "./RBAC_Lab_Report.txt" -InputObject $report -Encoding ASCII

Write-Host ""
Write-Host "Report exported: RBAC_Lab_Report.txt" -ForegroundColor Cyan

if ($allPass) {
    Write-Host "Overall: ALL PASS" -ForegroundColor Green
} else {
    Write-Host "Overall: FAILURES DETECTED" -ForegroundColor Red
}
