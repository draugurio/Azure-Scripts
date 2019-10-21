
<#
.SYNOPSIS
 Set encryption 1.5 to the VM
.DESCRIPTION
 The Script will get set the encryption 1.5 to the selected VM
.CHANGELOG

#>
############################
# VARIABLES
############################

$rgName = "" 
$vmName = ""
$keyVaultName = "" ##### Nombre del Key Vault donde se guardará la BEK de la encriptación
$rgnamekeyvault = "" ##### Nombre del RG del Key Vault donde se guardará la BEK de la encriptación

Enable-AzureRmAlias
$KeyVault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $rgnamekeyvault 
$diskEncryptionKeyVaultUrl = $KeyVault.VaultUri 
$KeyVaultResourceId = $KeyVault.ResourceId
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $rgname -VMName $vmName -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $KeyVaultResourceId -VolumeType All -skipVmBackup
