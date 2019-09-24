<#
.SYNOPSIS
 AzureRM version to purge secrets older than five days.

.DESCRIPTION
  This script will search and purge the secrets that are older than five days. This script will run in all the
  subscription's KeyVault that have the SoftDelete property enabled.

#>

Get-AzureRmSubscription | ForEach-Object {
Select-AzureRmSubscription $_
$KVS = Get-AzureRmKeyVault
    foreach($KV in $KVS){
            if((Get-AzureRmKeyVault -Vaultname $KV.Vaultname).EnableSoftDelete -eq "True"){
                Write-host "Searching in KeyVault " $KV.VaultName
                #Get all the deleted secrets in the previous 5 days
                $DeletedSecrets = Get-AzureKeyVaultSecret -VaultName $KV.VaultName -InRemovedState `
                | where {$_.DeletedDate -lt (Get-Date).AddDays(-5)}
                    if($DeletedSecrets){
                        foreach($DeletedSecret in $DeletedSecrets){
                        Write-host "Secret purged: $($DeletedSecret.Name)"
                        #Remove-AzureKeyVaultSecret -VaultName $KV.VaultName -InRemovedState -name $DeletedSecret.Name
                        }
                    }
                    else{
                        Write-host "No Secrets to purge in KeyVault" $KV.VaultName
                    }
                $DeletedCertificates = Get-AzureKeyVaultCertificate -VaultName $KV.VaultName -InRemovedState `
                | where {$_.DeletedDate -lt (Get-Date).AddDays(-5)}
                    if($DeletedCertificates){
                        foreach($DeletedCertificate in $DeletedCertificates){
                            Write-host "Certificated purged:" $DeletedCertificate.Name
                            #Remove-AzureKeyVaultCertificate -VaultName $KV.VaultName -InRemovedState -name $DeletedCertificate.Name
                        }
                    }
                    else{
                        Write-host "No Certificate to purge in KeyVault" $KV.VaultName
                    }
                $DeletedKeys = Get-AzureKeyVaultKey -VaultName $KV.VaultName -InRemovedState `
                | where {$_.DeletedDate -lt (Get-Date).AddDays(-5)}
                    if($DeletedKeys){
                        foreach($DeletedKey in $DeletedKeys){
                            Write-host "Key purged: $DeletedKey.Name"
                            #Remove-AzureKeyVaultKey -VaultName $KV.VaultName -InRemovedState -name $DeletedKey.Name
                        }
                    }
                    else{
                        Write-host "No Keys to purge in KeyVault" $KV.VaultName
                    }
        }
    }
}
