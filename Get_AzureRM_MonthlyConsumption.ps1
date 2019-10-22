 <#
.SYNOPSIS
    Get Azure consumption of the subscription.

.DESCRIPTION
    The script will go through all the subscriptions and get the consumption of all the resources, this 
    data will be stored in csv and later merged into a single excel file to upload it into a storage account blob
.CHANGELOG
    v1.0
    
#>
$currentTime = (Get-Date).ToUniversalTime()
$global:Directory = New-Item .\AzureConsumption -ItemType directory -Force

try{
        $listSubscriptions = Get-AzureRmSubscription
    }
catch{
        $Status = "Error: $($error[0].exception.message)"
        Write-output ($Status | format-list | Out-String)
        throw "Error couldn't get Azure subscriptions"
    }

#Get Dates
$month = (Get-Date).AddMonths(-1).ToString("MM")
$year = Get-Date -UFormat %Y
$days = [DateTime]::DaysInMonth($year, $month)
$startDate = (Get-Date -Year $year -Month $Month -Day 1).ToString("yyyy-MM-dd")
$EndOfMonth = (Get-Date -Year $year -Month $Month -Day $days).ToString("yyyy-MM-dd")
    Foreach($subscription in $listSubscriptions) {
        Set-AzureRmContext -SubscriptionID $subscription.Id
        $consumption = ''
        Write-Output "$($subscription.Name) Selected"
        try{
            $consumption = Get-AzureRmConsumptionUsageDetail -StartDate $startDate -EndDate $EndOfMonth -Expand MeterDetails -IncludeAdditionalProperties
        }
        catch{
            $Status = "Error: $($error[0].exception.message)"
            Write-output ($Status | format-list | Out-String)
        }
        if(![string]::IsNullOrEmpty($consumption)){
            $groupedConsumption = @()
            $groupedConsumption += $consumption | Group-Object -Property InstanceName| %{
                [pscustomobject] @{
                    SubscriptionName = $subscription.Name
                    ResourceGroup = $_.Group[0].InstanceId.Split("/")[4]
                    Resource = $_.Name
                    ResourceType = $_.Group[0].ConsumedService
                    PretaxCost = ($_.group | Measure-Object -Property PretaxCost -Sum).sum
                } 
            }
            #SAVE CSV
            $groupedConsumption | Sort-Object -Descending -Property PretaxCost `
            | export-csv -Path "$($Directory)\$($subscription.Name).csv"
        }
        
    }
    $fileName = "AzureConsumption-"+$month+"-"+$year
    $workingdir = "$Directory\*.csv"
    $CsvPaths = dir -path $workingdir
    
    #Create Excel
    Write-Output "Saving Excel $filename"
    $doc = New-SLDocument -WorkbookName $filename -Path $Directory -PassThru -Confirm:$false -Force
    Import-CSVToSLDocument -WorkBookInstance $doc -CSVFile @($CsvPaths) -AutofitColumns -ImportStartCell "A1"
    $doc | Save-SLDocument 
    Write-Output "File saved to $Directory \ $filename .xlsx"

    #Change to Comercia IT Core Elements PRO
    Set-AzureRmContext -SubscriptionID "dbc7e692-0f8a-4519-a281-2c6d15890518"
    #Save file in Storage Account 
    $storageAccountName  = "comitsspew3cmdbst1"
    $resourceGroup = "comit-p-rg0"
    Write-Output "Storage Account selected $storageAccountName of RG $resourceGroup."
    $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName 
    $context = $storageAccount.Context
    $containerName = "azureconsumption" 

    Write-Output -Message "Saving CSVs in Storage Account"
    foreach ($csvPath in $CsvPaths) {
        # Upload CSV to Storage Account 
        Set-AzureStorageBlobContent -Container $containerName -File $CsvPath -Blob "$year/$month/$($csvPath.Name)" -Context $context -Force
    }
    Write-Output -Message "Saving CSVs in Storage Account: Done"


    Write-Output "Saving Excel in Storage Account comitsspew3cmdbst1"
    Set-AzureStorageBlobContent -Container $containerName -File ./AzureConsumption/$filename".xlsx" -Blob "$year/$month/$filename.xlsx" -Context $context -Force

    Write-Output "### Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"