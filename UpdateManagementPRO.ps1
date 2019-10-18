<#
.SYNOPSIS


.DESCRIPTION
  

.PARAMETER SoftwareUpdateConfigurationRunContext
  This is a system variable which is automatically passed in by Update Management during a deployment.

.PARAMETER RunbookName
  Name of the runbook which will check if the VM are responsive.

.PARAMETER Hybrid
  Name of the Hybrid Worker Group where the run will be run.
#>

param(
    [string]$SoftwareUpdateConfigurationRunContext,
    [parameter(Mandatory=$true)]
    [string]$RunbookName,
    [parameter(Mandatory=$true)]
    [string]$Hybrid
)

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
$AutomationVariable = "runvariable"+(Get-date).ToString("yyyy-MM-dd")
$failed = @()
$Logfile = ".\Logs\UpdateMgmnt_PROScriptLog_"+(Get-date).ToString("yyyy-MM-dd")+".log"
$ServicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'

Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $ServicePrincipalConnection.TenantId `
    -ApplicationId $ServicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint

$AzureContext = Select-AzureRmSubscription -SubscriptionId $ServicePrincipalConnection.SubscriptionID
$context = ConvertFrom-Json  $SoftwareUpdateConfigurationRunContext
$vmIds = $context.SoftwareUpdateConfigurationSettings.AzureVirtualMachines
$ConfigName = $context.SoftwareUpdateConfigurationName
$AutomationVariable = "$ConfigName_"+(Get-date).ToString("yyyy-MM-dd")

# search through all the automation accounts in the subscription  
# to find the one with a job which matches our job ID
    $AutomationResource = Get-AzureRmResource -ResourceType Microsoft.Automation/AutomationAccounts 
        foreach ($Automation in $AutomationResource) 
        { 
            $Job = Get-AzureRmAutomationJob -ResourceGroupName $Automation.ResourceGroupName -AutomationAccountName $Automation.Name -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue 
            if (!([string]::IsNullOrEmpty($Job))) 
            { 
                $ResourceGroup = $Job.ResourceGroupName 
                $AutomationAccount = $Job.AutomationAccountName 
                break; 
            } 
        }

#Check IF the VM are up
    $vmIds| sort-object –Unique | ForEach-Object {
        $vmName = $_.split("/")[8]
        $vmRg = $_.split("/")[4]
        $tags = (Get-AzureRMVM -Name $vmName -ResourceGroupName $vmRg).Tags
        $port = 3389
                if($vmName -like "comswlvmpzwe*"){
                    $port = 22
                }
                elseif($tags.DescriptionByOwner -match "entry"){
                #if((Get-AzureRMVM -Name $vmName -ResourceGroupName $vmRg).Tags | where {$_.DescriptionByOwner -match "entry"}){
                    $port = 10010
                }
                elseif($tags.DescriptionByOwner -match "exit"){
                #elseif((Get-AzureRMVM -Name $vmName -ResourceGroupName $vmRg).Tags | where {$_.DescriptionByOwner -match "exit"}){
                    $port = 6050
                }
                
               Write-Log -Level INFO -Message "Doing PING to the VM $vmName on port $port"
               $params = @{"VMname"=$vmName;"port"=$port}
                try{
                    $output = Start-AzureRmAutomationRunbook -Name $RunbookName -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -RunOn $Hybrid -Parameters $params -Wait 
                        if(!$output){
                            Write-Log -Level WARN -Message "The VM $vmName is not operational after the update, restarting it"
                            Restart-AzureRmVM -Name $vmName -ResourceGroupName $vmRg
                            Start-Sleep -Seconds 240
                            Write-Log -Level WARN -Message "The VM $vmName has been restarted, testing connectivity again"
                            $output = Start-AzureRmAutomationRunbook -Name $RunbookName -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -RunOn $Hybrid -Parameters $params -Wait 
                            if(!$output){
                                Write-output "$vmName is still down"
                                Write-Log -Level ERROR -Message "The VM $vmName is not responsible after restarting it."
                                $failed += $vmName
                            }
                        }
                        elseif([string]::IsNullOrEmpty($output)){
                                Write-Log -Level ERROR -Message "Couldn't check VM response."
                                $failed += $vmName
                        }
                        else{
                            Write-output "$vmName is up."
                            Write-Log -Level INFO -Message "The VM $vmName is up." 
                        }
                }
                catch{
                        $Status = "Error: $($error[0].exception.message)"
                        Write-output ($Status | format-list | Out-String)
                        $failed += $vmName
                }
    }
    #Check if the VM had a LoadBalancer to add them
    try{
        $ListLB = (Get-AzureRmAutomationVariable -AutomationAccountName $AutomationAccount -Name $AutomationVariable -ResourceGroupName $ResourceGroup).Value
        foreach($LB in $ListLB){
                if($failed -contains $LB.VMname){
                    Write-Log -Level INFO -Message "The VM $($LB.vmName) seems to be unresponsive, won't be added to the Load Balancer $($LoadBalancer.Name)."
                }
                else{
                Write-Log -Level INFO -Message "The VM $($LB.vmName) belongs to a LoadBalancer."
                $nic = Get-AzureRmNetworkInterface -Name $LB.NICName -ResourceGroupName $LB.NICRG
                $LoadBalancer = Get-AzureRmLoadBalancer -Name $LB.lbName -ResourceGroupName $LB.lbRG 
                $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = Get-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $LoadBalancer | where {$_.Name -eq $LB.BackendAddressPoolName}
                Set-AzureRmNetworkInterface -NetworkInterface $nic
                Write-Output "$($LB.vmName) Added to the LoadBalancer $($LoadBalancer.Name)"
                }
        }
    }
    catch{
        $Status = "Error: $($error[0].exception.message)"
        Write-output ($Status | format-list | Out-String)
    }
    finally{
        if(![string]::IsNullOrEmpty($failed)){
            Write-Log -Level Error -Message "There was a problem during the deployment with the VM $failed"
            if(![string]::IsNullOrEmpty($AutomationVariable)){
                Write-Log -Level INFO -Message "The Automation Variable: $AutomationVariable will be stored with the Failed VM configuration"
            }
            throw "The script had a problem with the VM $failed"
        }
        else{
            if(![string]::IsNullOrEmpty($AutomationVariable)){
            Write-Output "Variable $AutomationVariable eliminada"
            Write-Log -Level INFO -Message "Automation variable $AutomationVariable removed"
            Remove-AzureRmAutomationVariable -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount –Name $AutomationVariable
            }
        }
    }
