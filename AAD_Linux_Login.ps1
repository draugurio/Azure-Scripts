<#
.SYNOPSIS
 Add Linux VM to the Azure AD domain
.DESCRIPTION
 The script will send the commands to join it to the domain, it must have connectivity to the target VM
.CHANGELOG

#>
############################
# VARIABLES
############################
$AdminName = "administrador"
$VMName = ""
$ResourceGroupVM = ""
$KeyVaultName = "" ##### Key Vault name where the VM's password is stored.
$KVResourceGroupName = "" ##### Key Vault's RG name where the VM's password is stored.
$DomainName = "COMERCIA.ONMICROSOFT.COM" ##### This variable has to match the AADDS name.
$User = "" ##### Ej: U01XXXXX
$UserAADPassword = "" #####  U01XXXXX password



$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupVM -Name $VMName
if ( $VM -eq $Null) {
    Write-Output "#### The VM doesn't exist in this RG"
}
else {

            $NicVM = $VM.NetworkProfile[0].NetworkInterfaces.id.Split("/")[8]
            $NIC = Get-AzureRmNetworkInterface -Name $NicVM -ResourceGroupName $ResourceGroupVM
            $IP = $NIC.IpConfigurations.PrivateIpAddress
            Write-Output "This is the private IP: $IP "

            ##### Get Key Vault and secrets to access the VM #####
            $SecretName = "Microsoft-Compute-VirtualMachines-$VMName-$AdminName"
            $vault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $KVResourceGroupName
            $AdminPassword = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
            $AdminCredentials = New-Object System.Management.Automation.PSCredential ($AdminName, $AdminPassword.SecretValue)
            $Password = $AdminPassword.SecretValueText

             ##### Create the connection #####
             $session = New-SSHSession -ComputerName $IP -Credential $AdminCredentials -Force
             $VMLargeName = $VMName + "." + $DomainName
             $DomainUser = $User + "@" + $DomainName

             ##### Run commands against this session #####
             $stream = New-SSHShellStream -SSHSession $session
             $stream.WriteLine("sudo su")
             Start-Sleep -Seconds 1
             Write-Output ($stream.Read())
             $stream.WriteLine("$Password")
             Start-Sleep -Seconds 2
             Write-Output ($stream.Read())
             $stream.WriteLine("cat /dev/null > /etc/hosts")
             Start-Sleep -Seconds 3
             Write-Output ($stream.Read())
             $stream.WriteLine("echo `"127.0.0.1 $VMLargeName $VMName
::1 $VMLargeName $VMName`" >> /etc/hosts")
             Start-Sleep -Seconds 2
             Write-Output ($stream.Read())             
             $stream.WriteLine("yum install realmd sssd krb5-workstation krb5-libs samba-common-tools -y")
             Start-Sleep -Seconds 120
             Write-Output ($stream.Read())
             $stream.WriteLine("realm discover $DomainName")
             Start-Sleep -Seconds 20
             Write-Output ($stream.Read())
             $stream.WriteLine("kinit $DomainUser")
             Start-Sleep -Seconds 7
             Write-Output ($stream.Read())
             $stream.WriteLine("$UserAADPassword")
             Start-Sleep -Seconds 5
             Write-Output ($stream.Read())
             $stream.WriteLine("realm join --verbose $DomainName -U '$DomainUser'")
             Start-Sleep -Seconds 5
             Write-Output ($stream.Read()) 
             $stream.WriteLine("$UserAADPassword")
             Start-Sleep -Seconds 5
             Write-Output ($stream.Read())
             $stream.close()
                                                                                    
             Remove-SSHSession -SSHSession $Session
        
}