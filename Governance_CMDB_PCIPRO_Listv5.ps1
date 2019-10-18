 <#
.SYNOPSIS
    Get Inventory of all the Azure Resources in all the subscriptions.

.DESCRIPTION
    All the resources in the subscriptions wil be in an Excel file which will be located in
    a storage account wich has the "Subscription Backup Storage" tag. The name of the container is "cmdb".


.CHANGELOG
    MODIFIED : 2019-03-27
    #Added CMDB in the security storage account. 

    MODIFIED : 2019-02-14
    #Added new field to know if a storage firewall is activated or not.
    #Added new description to PaaS services.

    MODIFIED : 2018-12-14
    #Solved VM IP when has more than 1 Nic.
    #Solved issues with wrong NSG assigned to subnets.
    #Solved error when a nic is not attached to a VM.
    #Added Subnets and Vnets to NSG Rules.

    MODIFIED : 2018-12-05 
    #Added token SAS to write in the Storage Account
    #Added Description for NSG Rules.

    MODIFIED : 2018-11-05 
    #Added New tab for NSG Rules.

    MODIFIED : 2018-10-29 
    #Added property to identify if a resource is Public or Private PaaS.
    #Added ports of the NSG Rules.

    #>


#----------------------------------------------------
#         FUNCTIONS
#----------------------------------------------------

Function moduleObjectCheck {
    [CmdletBinding()] 
    param ( 
         [Parameter(
         ValueFromPipeline=$True,
         Position=0,
         Mandatory=$True,
         HelpMessage="Name of Module")]
         [Alias("nameModule")] 
         [AllowEmptyCollection()]
         [string]$ModuleName
    )
    $FunctionName = Get-PSCallStack
    Write-Log -Message "Entering $FunctionName" -Level Debug
    $query = $global:ListGlobal | where {$_.ModuleName -eq $ModuleName}
    if($query) {
        $global:ModuleObject = $query
    }
    else {
        $ModuleList = @()
        $global:ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleList
        }
    }
}

Function AddSubscriptionNameToList {
    <# 
    .SYNOPSIS
    Add subscription to list of resources
    .DESCRIPTION
    Iterate list of resources to add subscription
    #>
    [CmdletBinding()] 
    param ( 
         [Parameter(
         ValueFromPipeline=$True,
         Position=0,
         Mandatory=$True,
         HelpMessage="Name of Subscription")]
         [Alias("subscription")] 
         [ValidateNotNullOrEmpty()]
         [string]$SubscriptionName,
         
        [Parameter(
         ValueFromPipeline=$True,
         Position=1,
         Mandatory=$True,
         HelpMessage="Object of Module")]
         [Alias("Object")] 
         [object]$ModuleObject,

         [Parameter(
         ValueFromPipeline=$True,
         Position=2,
         Mandatory=$True,
         HelpMessage="Object list of resources")]
         [Alias("resourcesList")] 
         [AllowEmptyCollection()]
         [object]$resources,

         [Parameter(
         ValueFromPipeline=$True,
         Position=3,
         Mandatory=$True,
         HelpMessage="Array of parameters")]
         [Alias("parametersSelect")] 
         [ValidateNotNullOrEmpty()]
         [scriptblock]$parameters
    )
    $FunctionName = Get-PSCallStack
    Write-Log -Message "Entering $FunctionName" -Level Debug
    $ModuleName = $ModuleObject.ModuleName
    $ModuleList = $ModuleObject.ModuleList
    Write-Log -Message "Adding subscription name to List $ModuleName" -Level Debug
    #Loop List Resources
    foreach ($resource in $resources) {
        #Add Suscription to each resource
        Add-Member -InputObject $resource -NotePropertyName "Subscription" -NotePropertyValue $SubscriptionName
        $resource = Invoke-Command -ScriptBlock $parameters
        $ModuleList += $resource
    }
    $global:ModuleObject = [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleList = $ModuleList
    }
}

Function SaveCSV {
    <# 
    .SYNOPSIS
    Test if the file was save
    .DESCRIPTION
    Test if the file was save checking the path
    #>
    [CmdletBinding()] 
    param ( 
        [Parameter(
         ValueFromPipeline=$True,
         Position=0,
         Mandatory=$True,
         HelpMessage="Name of Module")]
         [Alias("Object")] 
         [ValidateNotNullOrEmpty()]
         [object]$ModuleObj
    )
    $ModuleName = $ModuleObj.ModuleName
    $ModuleList = $ModuleObj.ModuleList
    $FunctionName = Get-PSCallStack
    Write-Log -Message "Entering $FunctionName" -Level Debug
    Write-Log -Message "Saving List $ModuleName CSV" 
    $csvPath = $Directory.FullName + "\" + $ModuleName + ".csv"    
    $ModuleList | Export-Csv -Path $csvPath -NoTypeInformation -UseCulture
    TestPathExistance $csvPath
    $global:csvPaths += $csvPath
}

Function TestPathExistance ($path) {
    <# 
    .SYNOPSIS
    Test if the file was save
    .DESCRIPTION
    Test if the file was save checking the path
    #>
    $FileExists = Test-Path $path 
    If ($FileExists -eq $True) {
        Write-Log -Message "File saved to $path"
        Write-Host ""
    }
    Else {
        Write-Log -Message "NOK" -Level Error
        Write-Host ""
    }
}

function Write-Log { 
    <# 
    .Synopsis 
       Write-Log writes a message to a specified log file with the current time stamp. 
    .DESCRIPTION 
       The Write-Log function is designed to add logging capability to other scripts. 
       In addition to writing output and/or verbose you can write to a log file for 
       later debugging. 
    .PARAMETER Message 
       Message is the content that you wish to add to the log file.  
    .PARAMETER Path 
       The path to the log file to which you would like to write. By default the function will  
       create the path and file if it does not exist.  
    .PARAMETER Level 
       Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational, Debug) 
    .PARAMETER NoClobber 
       Use NoClobber if you do not wish to overwrite an existing file. 
    .EXAMPLE 
       Write-Log -Message 'Log message'  
       Writes the message to .\Logs\Log-$ScriptName.log. 
    .EXAMPLE 
       Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log 
       Writes the content to the specified log file and creates the path and file specified.  
    .EXAMPLE 
       Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error 
       Writes the message to the specified log file as an error message, and writes the message to the error pipeline. 
    #> 
    [CmdletBinding()] 
    Param ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 

        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info","Debug")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
    Begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process {   
        $Path='.\Logs\MainLog.log'
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
        } 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
        }
        else { 
            # Nothing to see here yet. 
        } 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "dd-MM-yyyy HH:mm:ss" 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                Write-Host ""
            } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                Write-Host ""
            } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                Write-Host ""
            } 
            'Debug' { 
                if ($Debug){
                    Write-Host "$ScriptName $Message"
                    $LevelText = 'DEBUG:' 
                    Write-Host ""
                    # Write log entry to $Path 
                    $Message = "$ScriptName $Message"
                    "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
                }
            } 
        } 

        # Write log entry to $Path 
        if ($Level -ne "Debug") {
            $Message = "$ScriptName $Message"
            "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
        }
    } 
    End { 
    } 
}

#-----------------------------------------------------------
#         VARIABLES
#-----------------------------------------------------------

Write-Log -Message "Defining variables" -Debug
$scriptName = $MyInvocation.MyCommand.Name
$global:debug = ""
$listMain = @()
$fileName = "AzureInventoryPCIPRO_$(Get-date -Format "dd_MM_yyyy")"
$blobName = "$((Get-Date).Year)/$([datetime]::Today.ToString('MM'))/$fileName.xlsx"

$global:CsvPaths = @()
$global:ListGlobal = @()
$rgList = @()
#Folder for CMDB
$global:Directory = New-Item .\AzureCMDB -ItemType directory -Force

#-----------------------------------------------------------
#         AZURE LOGIN
#-----------------------------------------------------------
$currentTime = (Get-Date).ToUniversalTime()
$ConnectName = "AzureRunAsConnection" 

Write-Log -Message "Login using conection: $ConnectName" -Level Debug 
try {
    # Get the connection "AzureRunAsConnection "
    $SvPrlCn=Get-AutomationConnection -Name $ConnectName         
    "Logging in to Azure..."
    Login-AzureRmAccount -ServicePrincipal -TenantId $SvPrlCn.TenantId -ApplicationId $SvPrlCn.ApplicationId -CertificateThumbprint $SvPrlCn.CertificateThumbprint 
    "Logging Done"
}
catch {
    if (!$SvPrlCn) {
        $ErrorMessage = "Connection $ConnectName not found."
        throw $ErrorMessage
    } 
    else{
        Write-Error -Message $_.Exception
        throw $_.Exception
        Write-Log -Message "Login Failed" -Level Debug 
    }
}
#>
#-----------------------------------------------------------
#             MAIN
#-----------------------------------------------------------
Write-Host ""
Write-Host ""
Write-Host "#######################################################################"
Write-Host "########## AZURE INVENTORY FOR ALL ASSIGNED SUSCRIPTIONS ##############"
Write-Host "#######################################################################"
Write-Host ""
Write-Log -Message "Start Main" -Level Debug
$listSubscriptions = Get-AzureRmSubscription | select Name,id,TenantId,State
#Save List Subscriptions
$subscriptionObject = [pscustomobject]@{
    ModuleName = "1-Subscriptions"
    ModuleList = $listSubscriptions
}
SaveCSV $subscriptionObject
Foreach ($subscription in $listSubscriptions) {
    $global:SubscriptionName = $subscription.Name
    $global:SubscriptionId = $subscription.Id
    #Switching Subscription
    Write-Log -Message  "Switching Suscription to: $SubscriptionName" -Level Debug 
    Set-AzureRmContext -SubscriptionID $subscription.Id
    Write-Log -Message "Excecuting Suscription: $SubscriptionName"  
    $resources = Get-AzureRmResource | select Location,ResourceGroupName,Name,ResourceType,Tags,Sku,ResourceId
    #Loop List
    foreach ($resource in $resources) {        
        $Type = Split-Path($resource.ResourceType) -Leaf
        #Add Suscription
        Add-Member -InputObject $resource -NotePropertyName "Subscription" -NotePropertyValue $SubscriptionName
        Add-Member -InputObject $resource -NotePropertyName "TagTier" -NotePropertyValue $resource.tags.tier
        Add-Member -InputObject $resource -NotePropertyName "TagComplianceProfile" -NotePropertyValue $resource.tags.complianceProfile
        Add-Member -InputObject $resource -NotePropertyName "TagDescriptionByOwner" -NotePropertyValue $resource.tags.descriptionbyOwner
        Add-Member -InputObject $resource -NotePropertyName "TagEnvironment" -NotePropertyValue $resource.tags.environment
        Add-Member -InputObject $resource -NotePropertyName "TagOwner" -NotePropertyValue $resource.tags.Owner
        Add-Member -InputObject $resource -NotePropertyName "Type" -NotePropertyValue $type
    }
    $listMain += $resources | Sort-Object -Descending -Property Type |select Subscription,Location,ResourceGroupName,Name,Type,ResourceType,TagTier,TagComplianceProfile,TagDescriptionByOwner,TagOwner,TagEnvironment,Sku,ResourceId 
    ##################
    # RESOURCE GROUPS
    ##################
    $rGroups = Get-AzureRmResourceGroup
    #Create Resource Group List Variable
    if ($rgList -eq "") {
        $rgList = @()
    }
    #Loop List Resource Group
    foreach ($rGroup in $rGroups) {
        #Add Suscription to RG
        Add-Member -InputObject $rGroup -NotePropertyName "Subscription" -NotePropertyValue $SubscriptionName
        $rgList += $rGroup | Select Subscription,Location,ResourceGroupName,ResourceId
    }

    #################
    # Load Balancer
    #################
    
    $ModuleName = "LoadBalancers"
    $ListB = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmLoadBalancer
    if ($resources) {
            foreach ( $resource in $resources) {
                $LoadBalancers = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroupName
                 DisplayName = $resource.Name
                 PaaS = "Private"
                }
            $ListB += $LoadBalancers
            }
    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListB
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }
    #####################################################################################
    #                                      Service Plan
    #####################################################################################
    $ModuleName = "ServicePlan"
    $ListSP = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmAppServicePlan 
    if ($resources) {
            foreach ( $resource in $resources) {
                $ServicePlan = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroup
                 DisplayName = $resource.Name
                 Type = $resource.Type
                 Tier = $resource.Sku.Tier
                 PaaS = "Private"
                }
            $ListSP += $ServicePlan
            }
    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListSP
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                    API MANAGERS
    #####################################################################################
    $ModuleName = "APIManagers"
    $ListAPIM = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmApiManagement | select Name,ResourceGroupName,VpnType,SKU,StaticIPs,Capacity
    if ($resources) {
        $subnetsForVnet = @()
        foreach( $subnetOfVnet in $vnetwork.Subnets) {
            $subnetsForVnet += $subnetOfVnet.name
        }
        foreach ($resource in $resources) {
            $IPs = @()
            foreach ( $IP in $resource.StaticIPs) {
                $IPs += $IP
            }
            $resource.StaticIPs = $IPs -join "-"
             $APIM = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroupName
                 DisplayName = $resource.Name
                 VpnType = $resource.VpnType
                 SKU = $resource.SKU
                 StaticIPs = $resource.StaticIPs
                 Capacity = $resource.Capacity
                 PaaS = "Private"
                }
            $ListAPIM += $APIM
         }
    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListAPIM
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                    WebApps
    #####################################################################################
    $ModuleName = "WebApps"
    $ListWA = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmWebApp
        
    if ($resources) {   
        foreach($resource in $resources){
                 $WebApp = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroup
                 Name = $resource.Name
                 ASE = Split-path($resource.ServerFarmId) -Leaf
                 OutboundIpAddresses = $resource.OutboundIpAddresses
                 PaaS = "Private"
                }
            $ListWA += $WebApp
        }


    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListWA
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                 HD INSIGHT CLUSTER
    #####################################################################################
    $ModuleName = "HDInsight"
    $parameters = {$resource | select Subscription,ResourceGroupName,Name}
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmResource -ExpandProperties -ErrorAction SilentlyContinue | where {$_.ResourceType -eq "Microsoft.HDInsight/clusters"} | select Name,ResourceGroupName
    if ($resources) {   
        AddSubscriptionNameToList -SubscriptionName $SubscriptionName -ModuleObject $ModuleObject -resources $resources -parameters $parameters
        Write-Log -Message "Subscription Added" -Level Debug    
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                 PUBLIC IPS
    #####################################################################################
    $ModuleName = "PublicIPs"
    $parameters = {$resource | select Subscription,ResourceGroupName,Name,PublicIpAddressVersion,PublicIpAllocationMethod,IpAddress}
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmPublicIpAddress | select ResourceGroupName,Name,PublicIpAddressVersion,PublicIpAllocationMethod,IpAddress
    if ($resources) {   
        AddSubscriptionNameToList -SubscriptionName $SubscriptionName -ModuleObject $ModuleObject -resources $resources -parameters $parameters
        Write-Log -Message "Subscription Added" -Level Debug    
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                 KEY VAULT
    #####################################################################################
    $ModuleName = "KeyVault"
    $ListKV = @()  
    Write-Log -Message "Start $ModuleName" -Level Debug
    moduleObjectCheck -ModuleName $ModuleName 
        $resources = Get-AzureRmKeyVault
        if ($resources) {   
            foreach ( $resource in $resources) {
                $KeyVault = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroupName
                 VaultName = $resource.VaultName
                 Location = $resource.Location
                 PaaS = "Private"
                }
            $ListKV += $KeyVault
            }
    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListKV
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }

    #####################################################################################
    #                                 SQL SERVER
    #####################################################################################
    $ModuleName = "SQL-SERVER"
    $ListSQL = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $SqlServer = Get-AzureRmSqlServer | select ResourceGroupName,ServerName
    if ($SqlServer){   
        $resources = @()
        foreach($server in $Sqlserver) {  
            $resources += Get-AzureRmSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName | select ResourceGroupName,ServerName,DatabaseName,MaxSizeBytes
        }
        foreach($resource in $resources){
        $database = [pscustomobject]@{
                 Suscription = $SubscriptionName
                 ResourceGroup = $resource.ResourceGroupName
                 ServerName = $resource.ServerName
                 DatabaseName = $resource.DatabaseName
                 MaxSizeBytes = $resource.MaxSizeBytes
                 SKU = $resource.SkuName
                 PaaS = "Private"
                }
            $ListSQL += $database
        }

    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListSQL
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }
    

    #####################################################################################
    #                              LOCAL NETWORK GATEWAY
    #####################################################################################
    $ModuleName = "LocalNetworkGateway"
    $ListLNG = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    
        foreach ($rg in $rGroups.ResourceGroupName) {
            $resources = Get-AzureRmLocalNetworkGateway -ResourceGroupName $rg
        }
        if ($resources){
            foreach($resource in $resources){
                $LocalNetworkGateway = [pscustomobject]@{
                    Suscription = $SubscriptionName
                    ResourceGroup = $LocalNGW.ResourceGroupName
                    Name = $LocalNGW.Name
                    GatewayIpAddress = $LocalNGW.GatewayIpAddress
                    LocalNetworkAdressSpace = $LocalNGW.LocalNetworkAddressSpace.AddressPrefixesText -join "*"
                    PaaS = "Public"
                }
                $ListLNG += $LocalNetworkGateway
            }
            #Object Creation
            $ModuleObject = [pscustomobject]@{
                ModuleName = $ModuleName
                ModuleList = $ModuleObject.ModuleList + $ListOMS
                }
            #Add ModeleObject to ListGlobal
            $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
            $global:ListGlobal += $global:ModuleObject
        }

    #####################################################################################
    #                              OMS
    #####################################################################################
    $ModuleName = "OMS"
    $ListOMS = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmOperationalInsightsWorkspace
    if ($resources) {
        foreach ( $resource in $resources) {
        $OMS = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                PaaS = "Public"
                PortalURL = $resource.PortalUrl
                RersourceID = $resource.DataFactoryId   
            }
            $ListOMS += $OMS
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListOMS
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } 

    #####################################################################################
    #                              Storage Accounts
    #####################################################################################
    $ModuleName = "StorageAccount"
    $ListStorage = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmStorageAccount
    if ($resources) {
        foreach ( $resource in $resources) {
            $IPs = ""
            if($resource.NetworkRuleSet.DefaultAction -eq "Deny"){
                foreach($Iprule in $resource.NetworkRuleSet.IpRules){
                    $IPs += $Iprule.IPAddressOrRange + ";"
                }
            }
            $Storage = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name =  $resource.StorageAccountName
                SecureStatus = $resource.NetworkRuleSet.DefaultAction
                IP = $IPs
                EnableHttpsTrafficOnly = $resource.EnableHttpsTrafficOnly
                Creationtime = $resource.CreationTime
                RersourceID = $resource.Id   
            }
            $ListStorage += $Storage
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListStorage
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } 

    ###########################################################
    #                             Virtual Machines
    ###########################################################
    $ModuleName = "VMs"
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-Azurermvm
    #Loop VM
    foreach ($virtualMachineAll in $resources) {
        $virtualmachineName = $virtualmachineAll.Name
        Write-Log -Message "Starting loop for $virtualmachineName" -Level Debug
        #Write-Log -Message "Query" -Level Debug
        $virtualmachineRG = $virtualmachineAll.ResourceGroupName
        $virtualmachine = Get-Azurermvm -Name $virtualmachineName -ResourceGroupName $virtualmachineRG
        $vnics = @()
        foreach($vnic in $virtualmachine.NetworkProfile.NetworkInterfaces){
            $vnics += Get-AzureRmNetworkInterface | Where {$_.Id -eq $vnic.Id} 
            }
        $NetworkSecurityGroups = @()
        $VnicPrivateIpAddress = @()
        $VnicPrivateIpAllocationMethod = @()
        $VnicPublicIpAddress = @()
        $vnets = @()
        $subnets = @()
        $dns = @()
        foreach ($vnic in $vnics) {
            foreach ( $dnsServer in $vnic.DnsSettings.DnsServers) {
                $dns += $dnsServer                
            }
            foreach ($ipconf in $vnic.IpConfigurations) {
                $VnicPrivateIpAddress += $vnic.IpConfigurations.PrivateIpAddress
                $VnicPrivateIpAllocationMethod += $ipconf.PrivateIpAllocationMethod
                if($ipconf.PublicIpAddress.Id){
                    $publicIpName = $Vnic.IpConfigurations.PublicIpAddress.Id.Split('/') | select -Last 1
                    $VnicPublicIpAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $vnic.ResourceGroupName -Name $publicIpName).IpAddress
                }
                $sub = Split-Path($ipconf.Subnet.Id) -Leaf
                $subnets += $sub
            }
        }
        foreach ($subnet in $subnets) {
            Write-Log -Message "Analyzing $subnet" -level Debug
            $vnet = Get-AzureRmVirtualNetwork -ErrorAction SilentlyContinue| Where {$_.Subnets.Name -eq $subnet} 
            $vnets += $vnet.Name
            foreach ($subnetVnet in $vnet.Subnets) {
                if ($subnetVnet.name -eq $subnet) {
                    if ($subnetVnet.NetworkSecurityGroup.Id) {
                        $NetworkSecurityGroups += Split-Path($subnetVnet.NetworkSecurityGroup.Id) -Leaf
                    }
                    else {        
                        Write-Log -Message "$subnet doesn't have NSG" -level Debug
                    }
                }
            }
            if ($dns -inotcontains "") {
                foreach($dnsServVnet in $vnet.DhcpOptions.DnsServers) {
                    $dns += $dnsServVnet
                    Write-Log -Message "DNS $dnsServVnet added from VNET" -level Debug
                }
            }
        }
        # Get VM Status (for Power State)
        $vmStatus = Get-AzurermVM -Name $virtualmachineName -ResourceGroupName $virtualmachine.ResourceGroupName -Status
        #Get DataDisk
        if ($virtualmachine.StorageProfile.OsDisk.Vhd.Uri) {
            $DataDisk = Split-Path($virtualmachine.StorageProfile.OsDisk.Vhd.uri) -Leaf
        }
        else {
            $DataDisk = ""
            Write-Log -Message "$virtualmachineName don't have Vhd"
        }
        $VM = [pscustomobject]@{
            Suscription = $SubscriptionName
            ResourceGroup = $virtualmachine.ResourceGroupName
            Name = $virtualmachineName
            PowerState = (get-culture).TextInfo.ToTitleCase(($vmStatus.statuses)[1].code.split("/")[1])
            Size = $virtualmachine.HardwareProfile.VmSize
            OS = $virtualmachine.storageprofile.osdisk.ostype
            ImageSKU = $virtualmachine.StorageProfile.ImageReference.Sku +  "_v" + $virtualmachine.StorageProfile.ImageReference.Version
            OSDiskSizeGB = $virtualmachine.StorageProfile.OsDisk.DiskSizeGB
            DataDiskCapacity = $virtualmachine.StorageProfile.DataDisks.Capacity
            DataDisks = $DataDisk
            VnicPrivateIpAddress = $VnicPrivateIpAddress -join "-"
            DescriptionByOwner = $virtualmachine.Tags.DescriptionByOwner
            VnicPrivateIpAllocationMethod = $VnicPrivateIpAllocationMethod -join "-"
            VnicPublicIpAddress = $VnicPublicIpAddress -join "-"
            Scalon = $virtualmachine.Tags.Scalon
            DNS = $dns -join "-"
            Vnet = $vnets -join "*"
            Subnet = $subnets -join "*"
            NSGs = $NetworkSecurityGroups -join "*"
        }
        $ModuleObject.ModuleList += $VM
    }
    #Object Creation
    $ModuleObject = [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleList = $ModuleObject.ModuleList
    }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    
    ########################
    # Virtual Networks, Subnets and VNICs  #
    ########################

    $vnetworks = Get-AzureRmVirtualNetwork -ErrorAction SilentlyContinue
    #Create Lists Variables
    $ListVnet = @()
    $ListSubnet = @()
    $ListVnic = @()
    #Loop Vnet
    $rGroups = Get-AzureRmNetworkInterface | select ResourceGroupName -Unique
    foreach($vnetwork in $vnetworks) {
        $vnetworkName = $vnetwork.Name
        Write-Log -Message "Start vNet loop for $vnetworkName" -Level Debug 
        $dns = @()
        #$subnetNetWorkSecuritygroup = ""
        foreach ( $dnsServer in $vnetwork.DhcpOptions.DnsServers) {
            $dns += $dnsServer       
        }
        $addressPrefixes = @()
        foreach ( $addressPrefix in $vnetwork.AddressSpace.AddressPrefixes) {
            $addressPrefixes += $addressPrefix
        }
        $subnetsForVnet = @()
        foreach ( $subnetfovnet in $vnetwork.Subnets) {
            $subnetsForVnet += $subnetfovnet.name
        }  
        $vnicsNamesNet = @()
        #Loop Subnet
        $subs = $vnetwork.Subnets
        Write-Log -Message "Start Subnet loop" -Level Debug 
        foreach ($sub in $subs) {
            $vnicsNamesSub = @()
            $subnetName = $sub.Name
            if($sub.NetworkSecurityGroup.Id){
            $subnetNetWorkSecuritygroup = Split-Path($sub.NetworkSecurityGroup.Id) -Leaf
            }
            else{$subnetNetWorkSecuritygroup = ""}
            foreach ($rGroup in $rGroups) {
                $resourceGroupName = $rGroup.ResourceGroupName
                Write-Log -Message "Start RG loop for $resourceGroupName of subnet $subnetName of vnet $vnetworkName" -Level Debug 
                $checkVnics = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName
                Write-Log -Message "End get vNics" -Level Debug 
                if ($checkVnics) {
                    Write-Log -Message "There are vNics in $resourceGroupName of subnet $subnetName of vnet $vnetworkName" -Level Debug 
                    $vnics = $checkVnics | Where-Object {$_.IpConfigurations.Subnet.Id -eq $sub.id}
                    Write-Log -Message "Query Done" -Level Debug 
                    #Loop Vnics
                    foreach ($Vnic in $Vnics) {
                       # $VMname = Split-Path($Vnic.VirtualMachine.Id) -Leaf
                        #if ($VM = Get-azureRMVM -Name $VMname -ResourceGroupName $rGroup.ResourceGroupName -ErrorAction SilentlyContinue) {
                        if($Vnic.VirtualMachine.Id){
                        $VMname = Split-Path($Vnic.VirtualMachine.Id) -Leaf
                        $VM = Get-azureRMVM -Name $VMname -ResourceGroupName $rGroup.ResourceGroupName -ErrorAction SilentlyContinue
                            if ($sub.RouteTable.Id) {
                                $subnetRouteTable = Split-Path($sub.RouteTable.Id) -Leaf
                            }
                        }
                        else {
                            Write-Log -Message "VM $VMname Not Found" -Level Debug 
                        }
                        $publicIpAddress = ""
                        if($vnic.IpConfigurations.PublicIpAddress.Id){
                            $publicIpName = $Vnic.IpConfigurations.PublicIpAddress.Id.Split('/') | select -Last 1
                            $publicIpAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $vnic.ResourceGroupName -Name $publicIpName).IpAddress
                        }
                        #nic Object
                        $nic = [pscustomobject]@{
                            #Add Suscription
                            Suscription = $SubscriptionName
                            VirtualNetwork = $vnetworkName
                            VNResourceGroup = $vnetwork.ResourceGroupName
                            VNAddressPrefixes = $AddressPrefixes -join "-"
                            VNDNS = $dns -join "-"
                            SubnetName=$sub.Name
                            SubnetAddressprefix = $sub.AddressPrefix -join "*"                   
                            VMName = $VMName 
                            VMResourceGroupName = $VM.ResourceGroupName
                            VnicName = $Vnic.Name
                            VnicPrivateIpAddress = $Vnic.IpConfigurations.PrivateIpAddress
                            VnicPrivateIpAllocationMethod = $Vnic.IpConfigurations.PrivateIpAllocationMethod
                            VnicPublicIpAddress = $publicIpAddress
                            SubnetRouteTable = $subnetRouteTable
                            SubnetNetWorkSecuritygroup = $subnetNetWorkSecuritygroup
                            RerourceID = $vnic.Id
                        }
                        $vnicsNamesSub += $Vnic.Name
                        $ListVnic += $nic
                    }
                }
            }
            Write-Log -Message "End RG loop" -Level Debug 
               
            #Subnet Object  
            $subnets = [pscustomobject]@{                    
                #Add Suscription
                Suscription = $SubscriptionName
                SubnetName = $subnetName
                Addressprefix = $sub.AddressPrefix -join "*"
                VnetName = $vnetwork.Name
                NetWorkSecuritygroup = $SubnetNetWorkSecuritygroup 
                ResourceGroup=$vnetwork.ResourceGroupName
                Vnics = $vnicsNamesSub -join '*'
                RouteTable = $SubnetRouteTable
                ResourceID = $sub.Id                    
            }
            $ListSubnet += $subnets
            $vnicsNamesNet += $vnicsNamesSub -join '*'
        }         

        $virtualNetworkPeerings = @()
        foreach ( $peering in $vnetwork.VirtualNetworkPeerings) {
            $virtualNetworkPeerings += $peering.name + "/" + $peering.PeeringState
        }

        $vnets = [pscustomobject]@{
            Suscription = $SubscriptionName
            ResourceGroup = $vnetwork.ResourceGroupName
            NetworkName = $vnetworkName
            AddressPrefix = $addressPrefixes -join "-"
            DNS = $dns -join "-"
            Subnets = $subnetsForVnet -join '*'
            Vnics = $vnicsNamesNet -join '*'
            VirtualNetworkPeerings = $virtualNetworkPeerings -join '*'
            RerourceID = $vnetwork.Id     
        }
        $ListVnet += $vnets
    }


    #VNET
    $ModuleName = "VNET"
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    #Object Creation
    $ModuleObject = [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleList = $ModuleObject.ModuleList + $ListVnet
    }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    #Subnet
    $ModuleName = "Subnet"
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    #Object Creation
    $ModuleObject = [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleList = $ModuleObject.ModuleList + $ListSubnet
    }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    #VNICs
    $ModuleName = "VNICs"
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    #Object Creation
    $ModuleObject = [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleList = $ModuleObject.ModuleList + $ListVnic
    }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject

    #####################################################################################
    #                         NETWORK SECURITY GROUP
    #####################################################################################
    $ModuleName = "NetworkSecurityGroups"
    $ModuleName2 = "NetworkSecurityGroupsRules"
    #Create Lists Variables
    $ListNSG = $ListNSGRules = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmNetworkSecurityGroup
    if ($resources) {   
        foreach ( $resource in $resources) {
            $securityRules = @()
            $subnet = $vnet =""
            if ($resource.Subnets.Count -igt '0'){
             $subnet = $listsubnet | ?{$_.NetWorkSecuritygroup -eq $resource.name} | %{$_} 
             $vnet = $ListVnet | ?{$_.NetworkName -eq $subnet.ResourceID.Split('/')[8]} | %{$_} 
            }
            foreach ($securityRule in $resource.SecurityRules) {
                $securityRules += $securityRule.Name
                $securityRules += "Port:" + $securityRule.DestinationPortRange
                #Object for the NSG Rules tab
                $nsgrules = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                NSG = $resource.Name
                Vnet = $vnet.NetworkName + "-" + $vnet.AddressPrefix
                Subnet = $subnet.SubnetName + "-" + $subnet.Addressprefix
                Protocol = $securityRule.Protocol
                SecurityRules = $securityRule.Name
                DestinationPortRange = $securityRule.DestinationPortRange -join '*'
                DestinationAddress = $securityRule.DestinationAddressPrefix -join '*'
                Access = $securityRule.Access
                Direction = $securityRule.Direction
                Description = $securityRule.Description
            }
            $ListNSGRules += $nsgrules
            }
           $networkInterfaces = @()
           foreach ($networkInterface in $resource.NetworkInterfaces) {
                $networkInterfaces += Split-Path($networkInterface.Id) -Leaf                
            }
           $subnets = @()
           foreach ($subnet in $resource.Subnets) {
                $subnets += Split-Path($subnet.Id) -Leaf
           }
            $nsg = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                Subnets = $subnets -join '*'
                SecurityRules = $securityRules -join "*"
                NetworkInterfaces = $networkInterfaces -join '*'
                RerourceID = $resource.Id     
            }
            $ListNSG += $nsg
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListNSG
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject

        #Object Creation
        $ModuleObject2 = [pscustomobject]@{
            ModuleName = $ModuleName2
            ModuleList = $ModuleObject2.ModuleList + $ListNSGRules
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName2})
        $global:ListGlobal += $global:ModuleObject2

    }


    ##############################################################################################
    #                                      Data Factories                                        #
    ##############################################################################################  
    $ModuleName = "DataFactories"
    #Create Lists Variables
    $ListDF = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmDataFactoryV2
    if ($resources) {
        foreach ( $resource in $resources) {
        $dataFactory = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                DataFactoryName = $resource.DataFactoryName
                PaaS = "Public"
                RersourceID = $resource.DataFactoryId   
            }
            $ListDF += $dataFactory
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListDF
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } #Data Factory End

    ##############################################################################################
    #                                     Application Insights                                   #
    ##############################################################################################  
    $ModuleName = "ApplicationInsights"
    #Create Lists Variables
    $ListAI = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmApplicationInsights
    if ($resources) {
        foreach ( $resource in $resources) {
        $AppInsight = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                PaaS = "Public"
                AppId = $resource.AppId
                Id = $resource.Id   
            }
            $ListAI += $AppInsight
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListAI
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } #Application Insights

    ##############################################################################################
    #                                     Route Tables                                           #
    ##############################################################################################  
    $ModuleName = "RouteTables"
    #Create Lists Variables
    $ListRT = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmRouteTable
    if ($resources) {
        foreach($resource in $resources){
        $RouteTable = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                Id = $resource.Id
            }
            $ListRT += $RouteTable
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListRT
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } #Route Table End

    ##############################################################################################
    #                                     RUNBOOK                                                #
    ##############################################################################################  
    $ModuleName = "Runbook"
    #Create Lists Variables
    $ListRunbooks = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $runbooks = Get-AzureRmResource | where {$_.Type -eq "Microsoft.Automation/automationAccounts/runbooks"}
    if ($runbooks) {
        
        foreach($resource in $runbooks){

        $Runbook = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                ResourceId = $resource.ResourceId
            }
            $ListRunbooks += $Runbook
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $Runbook
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } #RunBook end

    ##############################################################################################
    #                                     EVENTHUB                                               #
    ##############################################################################################  
    $ModuleName = "EventHub"
    #Create Lists Variables
    $ListEventHub = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $eventhubs = Get-AzureRmResource | where {$_.ResourceType -eq "Microsoft.EventHub/namespaces"}
    if ($eventhubs) {
        foreach($resource in $eventhubs){
        $Eventhub = [pscustomobject]@{
                Suscription = $SubscriptionName
                ResourceGroup = $resource.ResourceGroupName
                Name = $resource.Name
                PaaS = "Public"
                Id = $resource.Id  
            }
            $ListEventHub += $Eventhub
        }
        #Object Creation
        $ModuleObject = [pscustomobject]@{
            ModuleName = $ModuleName
            ModuleList = $ModuleObject.ModuleList + $ListEventHub
        }
        #Add ModeleObject to ListGlobal
        $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
        $global:ListGlobal += $global:ModuleObject
    
    } #EventHub end

    ##############################################################################################
    #                              RBAC  Users                                                   #
    ##############################################################################################  
    $ModuleName = "RBAC Users"
    #Create Lists Variables
    $ListUsers = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmRoleAssignment -Scope "/subscriptions/$SubscriptionId" | Where-Object {$_.ObjectType -contains "User"} | Select -Property DisplayName,SignInName,RoleDefinitionName,RoleDefinitionId,Scope
       
       if ($resources) {
        foreach ( $resource in $resources) {
        $users = [pscustomobject]@{
                Suscription = $SubscriptionName
                DisplayName = $resource.displayname
                SignInName = $resource.SignInName
                RoleDefinitionName = $resource.RoleDefinitionName
                Scope = $resource.Scope
                RoleDefinitionId = $resource.RoleDefinitionId

            }
            $ListUsers += $users
        }
    

    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListUsers
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }
    #End RBAC USERS

    ##############################################################################################
    #                              RBAC  Permissions                                             #
    ##############################################################################################  

    $ModuleName = "RBAC Permissions"
    #Create Lists Variables
    $ListP = @()
    Write-Log -Message "Start $ModuleName" -Level Debug 
    moduleObjectCheck -ModuleName $ModuleName
    $resources = Get-AzureRmRoleAssignment -Scope "/subscriptions/$SubscriptionId" | Where-Object {$_.ObjectType -notcontains "User"} | Select -Property DisplayName,SignInName,RoleDefinitionName,Scope
    
           if ($resources) {
        foreach ( $resource in $resources) {
        $permission = [pscustomobject]@{
                Suscription = $SubscriptionName
                DisplayName = $resource.displayname
                RoleDefinitionName = $resource.RoleDefinitionName
                Scope = $resource.Scope
            }
            $ListP += $permission
        }

    #Object Creation
    $ModuleObject = [pscustomobject]@{
     ModuleName = $ModuleName
     ModuleList = $ModuleObject.ModuleList + $ListP
     }
    #Add ModeleObject to ListGlobal
    $global:ListGlobal = @($global:ListGlobal | where {$_.ModuleName -ne $ModuleName})
    $global:ListGlobal += $global:ModuleObject
    }
    #End RBAC Permissions
}    

#Save Lists RG and List Main as CSV

$mainObject = [pscustomobject]@{
    ModuleName = "2-Main"
    ModuleList = $listMain
}
SaveCSV $mainObject
$rgObject = [pscustomobject]@{
    ModuleName = "3-ResourceGroups"
    ModuleList = $rgList
}
SaveCSV $rgObject
#Save all lists in ListGlobal as CSV
foreach( $ModuleObj in $global:ListGlobal) {
    write-host "module1 objc List" $ModuleObj.ModuleList
    write-host "module1 objec name" $ModuleObj.ModuleName
    SaveCSV -ModuleObj $ModuleObj
}

#Change Select Storage Account
$storageAccountBackup  = Get-AzureRmStorageAccount | where {$_.Tags.Values -eq "Subscription Backup Storage"}
Write-Output "- Storage Account selected $($storageAccountBackup.StorageAccountName) of RG $($storageAccountBackup.ResourceGroupName)."
$SecretName = "MicrosoftStorage-storageAccounts-$($storageAccountBackup.StorageAccountName)-BFQT-SCO-RWDLACUP-Key1"
$vault = Get-AzureRmKeyVault | where {$_.Tags.Values -eq "KV SW Operaciones Servicios Transversales"}
$Secret = Get-AzureKeyVaultSecret -VaultName $vault.VaultName -Name $SecretName
$context = New-AzureStorageContext -StorageAccountName $storageAccountBackup.StorageAccountName -SasToken $Secret.SecretValueText
$containerName = "cmdb" 
Write-Log -Message "Saving CSVs in Storage Account"
foreach ($csvPath in $CsvPaths) {
    # Upload CSV to Storage Account 
    Set-AzureStorageBlobContent -Container $containerName -File $CsvPath -Context $context -Force
}
Write-Log -Message "Saving CSVs in Storage Account: Done"
    #Create Excel
    Write-Log -Message "Saving Excel $filename"
    $doc = New-SLDocument -WorkbookName $filename -Path $Directory -PassThru -Confirm:$false -Force
    Import-CSVToSLDocument -WorkBookInstance $doc -CSVFile @($CsvPaths) -AutofitColumns -ImportStartCell "A1"
    $doc | Save-SLDocument 
    Write-Log -Message "File saved to $Directory \ $filename .xlsx"
    # Upload Excel to Storage Account 
    Write-Log -Message "Saving Excel in Storage Account"
    Set-AzureStorageBlobContent -Container $containerName -File ./AzureCMDB/$filename".xlsx" -Blob $blobName -Context $context -Force
    Write-Log -Message "Saving Excel in Storage Account: Done"
    # Upload Log to Storage Account 
    Write-Log -Message "Saving MainLog in Storage Account"
    Set-AzureStorageBlobContent -Container $containerName -File .\Logs\MainLog.log -Context $context -Force
# Upload Excel to Security Storage
    $storageAccountBackup  = Get-AzureRmStorageAccount | where {$_.Tags.Values -eq "Activity and Diagnostic Logs"}
    $SecretName = "MicrosoftStorage-storageAccounts-$($storageAccountBackup.StorageAccountName)-BFQT-SCO-RWDLACUP-Key1"
    $Secret = Get-AzureKeyVaultSecret -VaultName $vault.VaultName -Name $SecretName
    $context = New-AzureStorageContext -StorageAccountName $storageAccountBackup.StorageAccountName -SasToken $Secret.SecretValueText
    Write-Log -Message "Saving Excel in Security Storage Account"
    Set-AzureStorageBlobContent -Container $containerName -File ./AzureCMDB/$filename".xlsx" -Context $context -Force
    Write-Log -Message "Excel saved in Security Storage"
    
# Upload Excel to Storage Account NO-PCI 
    $SecretName = "MicrosoftStorage-storageAccounts-comswtmonpoc02rsc-BFQT-SCO-RWDLACUP-ConnectionString1"
    $Secret = Get-AzureKeyVaultSecret -VaultName $vault.VaultName -Name $SecretName
    $StorageNOPCI = New-AzureStorageContext -ConnectionString $Secret.SecretValueText
    Write-Log -Message "Saving Excel in Storage Account GTsI"
    Set-AzureStorageBlobContent -Container $containerName -File ./AzureCMDB/$filename".xlsx" -Blob $blobName -Context $StorageNOPCI.Context -Force
    Write-Log -Message "Saving Excel in Storage Account: Done"

Write-Log -Message "Saving MainLog in Storage Account: Done"
Write-Output "### Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"