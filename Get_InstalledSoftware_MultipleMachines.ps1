<#
.SYNOPSIS

.DESCRIPTION

.CHANGELOG

#>

$VMS = "comswwvmpzwe03", "comswwvmpzwe04", "comswwvmpzwe06","comswwvmpzwe08","comswwvmpzwe11","comswwvmpzwe12","comswwvmpzwe13","comswwvmpzwe23","comswwvmpzwe24","comswwvmpzwe25","comswwvmpzwe18","comswwvmpzwe19","comswwvmpzwe26", "comswwvmpzwe27"
#$VMS[0] = Get-AzureRmVM -Status | Where-Object {$_.name -like "comswwvmpzwe*" -and $_.PowerState -eq "VM running" } 
if($VMS){
    foreach($VM in $VMS){
        $Session = New-PSSession $VM #Add Try Catch
        if($Session){
        Invoke-Command -Session $Session  -FilePath 'C:\Scripts\Get_InstalledSoftware_LocalMachine.ps1'
        Copy-Item -FromSession $Session "C:\Inventory\$VM.csv" -Destination "C:\Inventory\$VM.namecsv" -force
        }
    }
}

$workingdir = "C:\Inventory\*.csv"
$Directory = "C:\Inventory\"
$outputXLSX = "C:\Inventory\Installed_Sotfware_VMs.xlsx"
$csv = dir -path $workingdir
#Create Excel
Write-EventLog -Message "Saving Excel $filename"
$doc = New-SLDocument -WorkbookName $outputXLSX -Path $Directory -PassThru -Confirm:$false -Force
Import-CSVToSLDocument -WorkBookInstance $doc -CSVFile $csv -AutofitColumns -ImportStartCell "A1"
$doc | Save-SLDocument 
Write-EventLog -Message "File saved to $Directory \ $filename .xlsx"

