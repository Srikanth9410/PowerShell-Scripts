<#
.Synopsis
  This script will get the information regarding VM names of Backend pools using the their IP addresses.

.Description
  It helps to configure the multiple app gateway rules at one go. 

.PARAMETER FilePath
    No FilePath is required.
     

.INPUTS
    <none>

 

.OUTPUTS
    <none>

 

.NOTES
    Author: Sreekanth Reddy Panyam
    Last Edit: 2021-06-21
    Version: 1.0 - Initial release

 
#>

#Requires -Modules Az.Accounts, Az.Network, Az.Storage
#Requires -Version 5.1
 
# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

$connection = Get-AutomationConnection -Name AzureRunAsConnection

# Wrap authentication in retry logic for transient network failures
$logonAttempt = 0
while(!($connectionResult) -and ($logonAttempt -le 10))
{
    $LogonAttempt++
    # Logging in to Azure...
    $connectionResult = Connect-AzAccount `
                            -ServicePrincipal `
                            -Tenant $connection.TenantID `
                            -ApplicationId $connection.ApplicationID `
                            -CertificateThumbprint $connection.CertificateThumbprint

    Start-Sleep -Seconds 30
}

# set the context for service principal 
Set-AzContext -SubscriptionName "XXXXX"

# Collect the information related to App gateway and store it in a variable.
$AGWPRD = Get-AzApplicationGateway -Name "XXXXXX" -ResourceGroupName "XXXXX"

# Iterate over each BackendAddresspool to get their IP addresses and use those IP addresses to get the VM names and store them in a hashtable.
$BPaddresspool = @{}

for ($i=0; $i-lt $AGWPRD.BackendAddressPools.count; $i++){
$key = $AGWPRD.BackendAddressPools[$i].Name
$BPaddresspool.$key = @()
for ($j=0; $j-lt $AGWPRD.BackendAddressPools[$i].BackendAddresses.Count; $j++){
$a = ((Get-AzNetworkInterface | ?{$_.IpConfigurations.PrivateIpAddress -eq $AGWPRD.BackendAddressPools[$i].BackendAddresses[$j].IpAddress}).VirtualMachine).ID

$vmname = ($a -split '/') | select -Last 1
$BPaddresspool.$key += $vmname
} 
}

# convert the information into JSON format and store it in temp folder
$BPaddresspool |ConvertTo-Json | Out-File -FilePath "$Env:temp/FileName.json"

# set the context for storage account
Set-AzCurrentStorageAccount -ResourceGroupName "XXXXX" -AccountName "XXXXXX"

# upload the JSON file which contains VM names of Backend pool into the blob container.
Set-AzStorageBlobContent -Container "XXXX" -File "$Env:temp/FileName.json" -Force