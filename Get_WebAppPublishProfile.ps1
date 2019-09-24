#Get PublishProfile WebApp

$ResourceName = "cgp-switch-core-endsofday-webapi"
$WebAppUser = "MicrosoftSite-ApiApp-comswasppzwe01-cgp-switch-core-cancellations-webapi"
$VaultName = "comswkvapzwe05"
$TokenValue = "My.Pass.2018"

$Token = "Control-Token"
$ApiVersion = "2016-08-01"


$PublicProfile = Invoke-AzureRmResourceAction -ResourceGroupName $ResourceGroupName `
-ResourceType "$ResourceType/config" -ResourceName "$ResourceName/publishingcredentials" `
-Action list -ApiVersion $ApiVersion -Force -ErrorAction Stop

$webapp = Get-AzureRmWebApp | where {$_.name -eq $ResourceName}

Get-AzureRmWebAppPublishingProfile `
    -ResourceGroupName comsw-p-app-core-01 `
    -Name cgp-switch-core-undos-webapi `
    -OutputFile creds.xml `
    -Format WebDeploy | Out-File "C:\test.xml"

