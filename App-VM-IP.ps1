<#
.Synopsis
  Gets the IP addresses from the VM names for DR

.Description
  Once the failover is happened the VMs are created in the DR region. This script helps us to get the IP addresses for those VM names. 

.PARAMETER FilePath
    No FilePath is required.
     

.INPUTS
    <none>

 

.OUTPUTS
    <none>

 

.NOTES
    Author: Sreekanth Panyam
    Last Edit: 2021-06-21
    Version: 1.0 - Initial release

 
#>


#Requires -Modules Az.Accounts, Az.Network, Az.compute, Az.storage
#requires -Version 5.1


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

# select the subscription where the file which we created to store the VM names in the Step02 
Select-AzSubscription -SubscriptionName "XXXXXX"

# select and set the context for Blob storage
Set-AzCurrentStorageAccount -ResourceGroupName "XXXXXX" -AccountName "XXXXXX"

# Get the Blob content and store it in the variable
$BPaddpool = Get-AzStorageBlobcontent -Container XXXXX -Blob filename -Force

# Convert the content from JSON and store it in the variable
$BPaddpool = get-content $BPaddpool.Name | ConvertFrom-Json


# change the subscription to DR subscription
Select-AzSubscription -SubscriptionName "XXXXX"


#convert the custom object into Hash Table
$BpHash = @{}
foreach( $i in $BPaddpool.psobject.properties.name )
{

$BpHash[$i] = $Bpaddpool.$i
}


# List the VMs in the DR region and store it in a variable.
$newVmName = Get-Azvm


# Iterate over each VM name and check if it matches the BPaddppol and if it matches get the IP address for that VM and store it in the newaddresspool variable. 
$newaddresspool = @{}
foreach ($i in $BpHash.Keys){

$newaddresspool.$i =@()

for ($j=0; $j-lt $BpHash[$i].Count; $j++){
for ($k=0; $k-lt $newVmName.count; $k++){
if($newVmName[$k].Name -match $BpHash[$i][$j]){

$NicName = (Get-AzVm -Name $newVmName[$k].Name).NetworkProfile.NetworkInterfaces 
$NicName | ConvertTo-Json
$NicF = $NicName.Id -split '/' | select -Last 1
$Niccon = Get-AzNetworkInterface -name $NicF
$Pip = $Niccon.IpConfigurations[0].PrivateIpAddress
$newaddresspool.$i += $Pip
}
}
}
}

# Collect all the properties of APP-Gateway from DR subscription and store it in a variable
$APPGW = Get-AzApplicationGateway -Name "XXXXXX" -ResourceGroupName "XXXXXX"

# Iterate over each Backend pool and configure the respective IP address
foreach ($l in $newaddresspool.Keys){
for ($m =0; $m-lt $newaddresspool[$l].count; $m++){

Set-AzApplicationGatewayBackendAddressPool -ApplicationGateway $AppGw -Name $l -BackendIPAddresses $newaddresspool[$l][$m]
}
}

# We need to update the app gateway with new configs without this the changes made to the appgateway won't be saved
Set-AzApplicationGateway -ApplicationGateway $AppGw
