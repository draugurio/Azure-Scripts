#Get Nested Properties
Get-AzureRmVM | Sort-Object -Property Name |`
 Select -Property Name, ResourceGroupName, @{Name="Scalon"; Expression={$_.Tags.Scalon}}