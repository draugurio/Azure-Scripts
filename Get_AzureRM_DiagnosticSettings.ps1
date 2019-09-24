<#
.SYNOPSIS
 Get the Diagnostics Settings for all the resources in the subscription
.DESCRIPTION
 The Script will get the Diagnostic Settings for all the resources that have it configured in
 the subscription, it will create a CSV file with the name, type, storage account and workspace
 where are being saved.
.CHANGELOG

#>


$DiagnosticSettings = @()
Get-AzureRmResource | % {
    
    if(Get-AzureRmDiagnosticSetting -ResourceId $_.Id -ErrorAction SilentlyContinue){
        $DiagnosticSetting = Get-AzureRmDiagnosticSetting -ResourceId $_.Id
        if(![string]::IsNullOrEmpty($DiagnosticSetting)) { 
            $DiagnosticSettings += [pscustomobject]@{
                Name = $_.Name
                ResourceType = $_.ResourceType
                StorageAccount = Split-Path($DiagnosticSetting.StorageAccountId) -Leaf
                Workspace = Split-Path($DiagnosticSetting.WorkspaceId) -Leaf
                Enabled = "Yes"
            }
        }
        else{
            $DiagnosticSettings += [pscustomobject]@{
                Name = $_.Name
                ResourceType = $_.ResourceType
                StorageAccount = "N/A"
                Workspace = "N/A"
                Enabled = "Yes"
            }
        }
    }
}

$DiagnosticSettings | Export-CSV -NoTypeInformation -UseCulture -Path C:\Scripts\DiagnosticSettings.csv