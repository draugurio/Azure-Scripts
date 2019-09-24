#Set new Rule in a NSG
$NSG = ""

Get-AzureRmNetworkSecurityGroup | Where-Object {$.Name -eq $NSG } |`
Add-AzureRmNetworkSecurityRuleConfig -Name Allow_DS_Inbound `
-Description "SSI - DC Communication" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
-SourceAddressPrefix 10.25.28.32/28 -SourcePortRange * `
-DestinationAddressPrefix VirtualNetwork DestinationPortRange 42,53,88,123,135,137-139,389,445,464,636,3268-3269,9389,5722,49152-65535 `
| Set-AzureRmNetworkSecurityGroup

Get-AzureRmNetworkSecurityGroup -Name NSG -ResourceGroupName 4SysOps | Add-AzureRmNetworkSecurityRuleConfig -Name AllowingWinRMHTTP -Description "To Enable PowerShell Remote Access" -Access Allow -Protocol Tcp -Direction Inbound -Priority 103 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix *  DestinationPortRange 5985 | Set-AzureRmNetworkSecurityGroup