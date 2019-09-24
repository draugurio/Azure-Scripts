<#
.SYNOPSIS
    Set Backups for the WebApps in the subscription.

.DESCRIPTION
    The script will go through all the webApps and check whether they Backups or not. In case the Backup
    is not active it will activate it. Needs access to the KeyVault to retrieve the SAStoken. 
    v1.0
    
#>
$startDate = (Get-date -Hour 5 -Minute 0).AddDays(1) # when should the first backup be triggered

    try{
    $webApps = Get-AzureRmWebApp
    $storageAccountBackup  = Get-AzureRmStorageAccount | where {$_.Tags.Values -eq "Subscription Backup Storage"}
    $SecretName = "MicrosoftStorage-storageAccounts-$($storageAccountBackup.StorageAccountName)-BFQT-SCO-RWDLACUP-Key1"
    $vault = Get-AzureRmKeyVault | where {$_.Tags.Values -eq "KV SW Operaciones Servicios Transversales"}
    $Secret = Get-AzureKeyVaultSecret -VaultName $vault.VaultName -Name $SecretName
    $SasToken = "https://$($storageAccountBackup.StorageAccountName).blob.core.windows.net/backups$($Secret.SecretValueText)"
    }
    catch{
        $Status = "Error: $($error[0].exception.message)"
        Write-output ($Status | format-list | Out-String)
        throw
    }

    foreach($webApp in $webApps){

        if(Get-AzureRmWebAppBackupConfiguration -WebApp $webApp -ErrorAction SilentlyContinue){
            Write-Output "WebApp $($webApp.Name) already had backup configured"
        }
        else {
            Write-output "Creating $($webApp.Name) backup schedule"
            try{
            Edit-AzureRmWebAppBackupConfiguration -WebApp $webApp `
            -StorageAccountUrl $SasToken -FrequencyInterval 1 -FrequencyUnit Day -RetentionPeriodInDays 30 `
            -KeepAtLeastOneBackup -StartTime $startDate -ErrorAction Continue
            }
            catch{
                $Status = "Error: $($error[0].exception.message)"
                Write-output ($Status | format-list | Out-String)
                throw "Error with Webapp $($webApp.Name)"
            }

        }
    }
