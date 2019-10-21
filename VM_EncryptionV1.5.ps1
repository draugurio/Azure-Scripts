
<#
.SYNOPSIS
 Set encryption 1.5 to the VM
.DESCRIPTION
 The Script will get set the encryption 1.5 to the selected VM
.CHANGELOG

#>

############################
# VARIABLES2
############################

$rgName = ""
$vmName = ""

##### Los que se muestran como ejemplo en las siguientes variables son los datos correctos para el tenant de PCI PRO (CPG-COMSW-P-01) #####

$aadClientID = "" ##### AADClientID de la aplicación creada en el AAD para la encriptación. Ej: "461ccb8b-17dd-487c-b448-50eb89acb214"
$aadClientSecret = "" ##### AADClientSecret de la aplicación creada en el AAD para la encriptación. Ej: "_5.P0b4z+Dg?TXrmuUsC0+HMC]1cHcaP"
$KeyVaultName = ""  ##### Nombre del Key Vault donde se guardará la BEK de la encriptación. Ej: "comswkvapzwe15"
$KeyVaultRGName = ""  ##### Nombre del RG del Key Vault donde se guardará la BEK de la encriptación. Ej. "comsw-p-sec-cross-01"

Enable-AzureRmAlias
$KeyVault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultRGName
$diskEncryptionKeyVaultUrl = $KeyVault.VaultUri
$KeyVaultResourceId = $KeyVault.ResourceId
 
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $rgname -VMName $vmName -AadClientID $aadClientID -AadClientSecret $aadClientSecret -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $KeyVaultResourceId -VolumeType All –SkipVmBackup
