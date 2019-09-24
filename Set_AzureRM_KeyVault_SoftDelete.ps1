$KVS = Get-AzKeyVault 
foreach($KV in $KVS){
    $KV.EnableSoftDelete
    Set-AzKeyVault
}
Enable-AzureRmAlias
$vaultName = "keyvault0lab"

($resource = Get-AzureRMResource -ResourceId (Get-AzureRMKeyVault -VaultName $vaultName).ResourceId).Properties | Add-Member -MemberType "NoteProperty" -Name "enableSoftDelete" -Value "true"
$kv = Get-AzKeyVault -VaultName $vaultName
$kv | Add-Member -MemberType "NoteProperty" -Name "enableSoftDelete" -Value "true" -Force
Set-AzureRmResource -resourceid $resource.ResourceId -Properties $resource.Properties
Set-AzResource -ResourceId $kv.ResourceId -Properties $kv.Properties

Login-AzAccount

az resource update --id $(az keyvault show --name keyvault0lab -o tsv | awk '{print $1}') --set properties.enableSoftDelete=true