Login-AzAccount

$NW = Get-AzNetworkWatcher -ResourceGroupName NetworkWatcherRg -Name NetworkWatcher_westeurope
$nsgs = Get-AzNetworkSecurityGroup
$storageAccount = Get-AzStorageAccount -ResourceGroupName comsw-p-sec-cross-01 -Name comswsacpzwe06
$workspace = Get-AzOperationalInsightsWorkspace -Name comswomspzwe01 -ResourceGroupName comsw-p-mon-cross-01
$workspaceid = $workspace.CustomerId.Guid
$location = $workspace.Location
$workspaceResourceId = $workspace.ResourceId
Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $NW -TargetResourceId $nsg.Id -EnableFlowLog $true -StorageAccountId $storageaccount.ID -FormatVersion 2 -RetentionInDays 7

    foreach($nsg in $nsgs){
        #Configure Version 2 FLow Logs with Traffic Analytics Configured
        Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $NW -TargetResourceId $nsg.Id -StorageAccountId `
        $storageAccount.Id -EnableFlowLog $true -FormatType Json -FormatVersion 2 -EnableTrafficAnalytics `
        -WorkspaceResourceId $workspaceResourceId -WorkspaceGUID $workspaceid -WorkspaceLocation $location `
        -RetentionInDays 7
    }

#Query Flow Log Status
#Get-AzNetworkWatcherFlowLogStatus -NetworkWatcher $NW -TargetResourceId $nsg.Id

