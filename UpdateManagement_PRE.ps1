<#
.SYNOPSIS


.DESCRIPTION
  This script is intended to be run as a part of Update Management Pre/Post scripts. 


.PARAMETER SoftwareUpdateConfigurationRunContext
  This is a system variable which is automatically passed in by Update Management during a deployment.
#>

param(
    [string]$SoftwareUpdateConfigurationRunContext
)

$ResourceGroup = "comsw-p-cross-01"
$AutomationAccount = "comswauapzwe01"
$rsvName = "comswrsvpzwe01" 
$rsvRG = "comsw-p-cross-01"
#$Logfile = "Log.txt"
Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}


$ServicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'

Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $ServicePrincipalConnection.TenantId `
    -ApplicationId $ServicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint

$AzureContext = Select-AzureRmSubscription -SubscriptionId $ServicePrincipalConnection.SubscriptionID
#endregion BoilerplateAuthentication

#If you wish to use the run context, it must be converted from JSON
$context = ConvertFrom-Json  $SoftwareUpdateConfigurationRunContext
$vmIds = $context.SoftwareUpdateConfigurationSettings.AzureVirtualMachines
$runId = $context.SoftwareUpdateConfigurationRunId
$ConfigName = $context.SoftwareUpdateConfigurationName
$AutomationVariable = "$ConfigName_"+(Get-date).ToString("yyyy-MM-dd")

$ListLB = @()
    if (!$vmIds) 
    {
        #Workaround: Had to change JSON formatting
        $Settings = ConvertFrom-Json $context.SoftwareUpdateConfigurationSettings
        #Write-Output "List of settings: $Settings"
        $VmIds = $Settings.AzureVirtualMachines
        #Write-Output "Azure VMs: $VmIds"
        if (!$vmIds) 
        {
            Write-Log -Level ERROR -Message "No Azure VMs found, stopping update"
            throw "No Azure VMs found"
            #return
        }
    }

#Start script on each machine
    $vmIds| sort-object –Unique | ForEach-Object{
        $vmId =  $_
        $split = $vmId -split "/";
        $subscriptionId = $split[2]; 
        $vmRg = $split[4];
        $vmName = $split[8];
        #Write-Output ("Subscription Id: " + $subscriptionId)
        $mute = Select-AzureRmSubscription -Subscription $subscriptionId
        
        #Check if the VM has a recent Backup
        Get-AzureRMRecoveryServicesVault -Name $rsvName -ResourceGroupName $rsvRG `
        | Set-AzureRMRecoveryServicesVaultContext

        $backupcontainer = Get-AzureRMRecoveryServicesBackupContainer `
        -ContainerType "AzureVM" `
        -FriendlyName $vmName
 
        $backupitem = Get-AzureRmRecoveryServicesBackupItem `
        -Container $backupcontainer `
        -WorkloadType "AzureVM"

        if($backupitem.LastBackupTime -ge(Get-Date).AddDays((-1))){
            Write-Output "VM $vmName has a recent backup"
            Write-Log -Level INFO -Message "VM $vmName has a recent backup"
        }
        else{
            Write-Log -Level ERROR -Message "The VM $vmName does not have a recent backup, stopping script"
            throw "The VM $vmName does not have a recent backup, stopping script"
        }
        #Check if the VM is attached to a Load Balancer
        $nic = Get-AzureRmNetworkInterface | where {$_.Name -eq (Split-Path ((Get-AzureRmVM -ResourceGroupName $vmRg -Name $VMname).NetworkProfile.NetworkInterfaces[0].Id) -Leaf)}
        if ($nic.IpConfigurations[0].LoadBalancerBackendAddressPools.Count -gt "0"){
            Write-Output "VM $vmName is attached to a LoadBalancer, saving the information"
            Write-Log -Level INFO -Message "VM $vmName is attached to a LoadBalancer, saving the information"
            $LBBackend = ConvertFrom-Json $nic.IpConfigurations[0].LoadBalancerBackendAddressPoolsText
            #$LB = Get-AzureRmLoadBalancer | where {$_.Name -eq $LBBackend.id.Split("/")[-3] }
                $LBInfo = [PSCustomObject]@{
                    vmName =  $VMname
                    vmRG =    $VMrg
                    nicName = $nic.Name
                    nicRG  =  $nic.ResourceGroupName
                    lbName =  $LBBackend.id.Split("/")[-3]
                    lbRG =    $LBBackend.id.Split("/")[-7]
                    BackendAddressPoolName = $LBBackend.id.Split("/")[-1]
                }
            $ListLB += $LBInfo 
        }
    }

    #Remove LB from the Machine
    if($ListLB){
        #Create variable named after this run so it can be retrieved 
        Write-Log -Level INFO -Message "Creating variable"
        Write-Output "Creating variable"
        New-AzureRmAutomationVariable -ResourceGroupName $ResourceGroup –AutomationAccountName $AutomationAccount –Name $AutomationVariable -Value "" –Encrypted $false
        Set-AzureRMAutomationVariable –Name $AutomationVariable -Value $ListLB -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Encrypted $false 
        foreach($LB in $ListLB){
            try{
                $NIC = Get-AzureRmNetworkInterface -Name $LB.NICName -ResourceGroupName $LB.NICRG
                $NIC.IpConfigurations[0].LoadBalancerBackendAddressPools = $null 
                Set-AzureRmNetworkInterface -NetworkInterface $NIC
                Write-Log -Level INFO -Message "$($LB.vmName) succesfully removed from LoadBalancer"
                Write-output "$($LB.vmName) succesfully removed from LoadBalancer"
            }
            catch{
                $Status = "Error: $($error[0].exception.message)"
                Write-output ($Status | format-list | Out-String)
                Write-Log -Level ERROR -Message "Error removing LoadBalancer from VM $($ListLB.vmName)"
                throw "Error removing LoadBalancer from VM $($ListLB.vmName)"
            }
        }
    }

