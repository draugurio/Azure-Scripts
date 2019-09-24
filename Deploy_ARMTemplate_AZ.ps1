
$templatePath = "C:\Users\f.salas.chaviel\Documents\Caixa Project\Templates\Microsoft.Compute\Parent_VirtualMachineVSTS_AvailabilitySet_(vPCI)NOENCRIPv1.0.json"
$parametersPath = "C:\Users\f.salas.chaviel\Documents\Caixa Project\Templates\Microsoft.Compute\Parent_VirtualMachineVSTS_AvailabilitySet_(vPCI)NOENCRIPv1.0_parameters.json"

#Old Azure RM Module
#New-AzureRmResourceGroupDeployment -ResourceGroupName "commp-t-backuptest" -Name "BackupDeployment" -Templatefile $templatePath -TemplateParameterfile "C:\Users\f.salas.chaviel\Desktop\new\Parent_VirtualMachinePhase2_v1.3.parameters.json"


New-AzResourceGroupDeployment -ResourceGroupName "commp-t-rg1" `
-Templatefile $templatePath -TemplateParameterfile $parametersPath

