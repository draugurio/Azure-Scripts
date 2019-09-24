$VMs = Get-AzureRmVM | Where-Object {$_.name -like "comswlvmpzwe0[1-4]" }
$ListNIC = @()
    if($VMs){
    foreach($VM in $VMs){
        foreach($nic in $VM.NetworkProfile.NetworkInterfaces){
            $name = $nic.id.Split('/') | select -Last 1
            $vnic = Get-AzureRmNetworkInterface | Where-Object {$_.name -eq $name}
            $publicIpAddress = ""
            if($vnic.IpConfigurations.PublicIpAddress.Id){
                $publicIpName = $Vnic.IpConfigurations.PublicIpAddress.Id.Split('/') | select -Last 1
                $publicIpAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $vnic.ResourceGroupName -Name $publicIpName).IpAddress
            }
            $Vnicfinal = [pscustomobject]@{
                Vnic = $vnic.Name
                VnicResourceGroup = $vnic.ResourceGroupName
                VnicPrivateIpAddress = $vnic.IpConfigurations.PrivateipAddress
                VnicPrivateIpAllocationMethod = $Vnic.IpConfigurations.PrivateIpAllocationMethod
                VnicPublicIpAddress = $publicIpAddress
                Vnet = $vnic.IpConfigurations.Subnet.Id.Split("/")[8]
                Subnet = Split-Path($vnic.IpConfigurations.Subnet.Id) -leaf
                VMName = $VM.Name 
                VMResourceGroupName = $VM.ResourceGroupName
                ResourceID = $vnic.Id
            }
            $ListNIC += $Vnicfinal
        }
    }
}   
    
$global:Directory = New-Item .\AzureNIC -ItemType directory -Force
$fileName = "AppliancesNicPCI-" + (Get-Date).ToString("yyyy-MM-dd")
$ListNIC | export-csv -Path "$($Directory)\test.csv"
$File = "$($Directory)\test.csv"
Write-Output "Saving Excel $filename"
$doc = New-SLDocument -WorkbookName $filename -Path $Directory -PassThru -Confirm:$false -Force
Import-CSVToSLDocument -WorkBookInstance $doc -CSVFile $File -AutofitColumns -ImportStartCell "A1"
$doc | Save-SLDocument
Write-Output "File saved to $Directory \ $filename .xlsx"

# Get Storage and set Storage Context
$storageAccountBackup  = Get-AzureRmStorageAccount | where {$_.Tags.Values -eq "pruebascriptnic01"}
Write-Output "- Storage Account selected $($storageAccountBackup.StorageAccountName) of RG $($storageAccountBackup.ResourceGroupName)."
$SecretName = "MicrosoftStorage-storageAccounts-$($storageAccountBackup.StorageAccountName)-BFQT-SCO-RWDLACUP-Key1"
$vault = Get-AzureRmKeyVault | where {$_.Tags.Values -eq "KV SW Operaciones Servicios Transversales"}
$Secret = Get-AzureKeyVaultSecret -VaultName $vault.VaultName -Name $SecretName
$context = New-AzureStorageContext -StorageAccountName $storageAccountBackup.StorageAccountName -SasToken $Secret.SecretValueText
$containerName = "nicconfig"

Write-Output "Saving Excel in Storage Account"
Set-AzureStorageBlobContent -Container $containerName -File ./AzureNIC/$filename".xlsx" -Context $context -Force 
#Remove old files
$RetainedElements = 10
$FilesStored = Get-AzureStorageBlob -Container $containerName -Context $context -Blob ("AppliancesNicPCI-"+"*")
$SortedFilesStored = $FilesStored | Sort-Object LastModified -descending
$Counter = 0
foreach ($File in $SortedFilesStored) {
    $File.Name
    $Counter += 1
    if($Counter -gt $RetainedElements) {
        #Remove older backups
        Remove-AzureStorageBlob  -Container $containerName -Context $context -Blob $File.Name
    }
} 

