<# 
.SYNOPSIS 
Function for rotation of the storage account keys 
 
.DESCRIPTION 
Function which rotates the storage account keys and store them in the key vault as a secret form 
 
.PARAMETER StorageAccount 
Name of the storage account 
 
.PARAMETER KeyVault 
Name of the key vault 
 
.EXAMPLE 
Switch-AzStorageAccountKey -Name nemanjajovicsa -KeyVault nemanjajovickv 
#> 
Function Switch-AzStorageAccountKey { 
    [CmdletBinding()] 
    param ( 
        # Name of the storage account 
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()] 
        [string]$StorageAccount, 
        # Name of the key vault 
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()] 
        [string]$KeyVault 
    ) 
    begin { 
        $FindStorageAccount = (Get-AzStorageAccount | where-object {$_.StorageAccountName -eq "$StorageAccount"}) 
        if ([string]::IsNullOrWhiteSpace("$FindStorageAccount")) { 
            Write-Error "Cannot find instance of the storage account with the name $StorageAccount" -ErrorAction Stop 
        } 
        $FindKeyVault = (Get-AzKeyVault -Name "$KeyVault" -ErrorAction SilentlyContinue) 
        if ([string]::IsNullOrWhiteSpace("$FindKeyVault")) { 
            Write-Error "Cannot find instance of the key vault with the name $KeyVault" -ErrorAction Stop 
        } 
    } 
    process { 
        $KeyList = @("key1","key2") 
        foreach ($Key in $KeyList) { 
            try { 
                Write-Verbose "Generating new key value for the key - $Key" 
                $GenerateKey = $FindStorageAccount | New-AzStorageAccountKey -KeyName "$Key" -ErrorAction Stop 
                [string]$KeyValue = ($GenerateKey.Keys | where-object {$_.keyname -eq $Key}).Value 
                $SecureKey = ConvertTo-SecureString -String $KeyValue -AsPlainText -Force 
                [string]$SecretName = $FindStorageAccount.StorageAccountName + $Key 
                Write-Verbose "Writing in the key vault - $($FindKeyVault.VaultName) , secret for the key $Key" 
                [void](Set-AzKeyVaultSecret -VaultName $FindKeyVault.VaultName -Name $SecretName -SecretValue $SecureKey -ErrorAction Stop) 
            } 
            catch { 
                Write-Error "$_" -ErrorAction Stop 
            } 
        } 
    } 
}

