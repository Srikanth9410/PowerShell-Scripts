<#
.Synopsis
  Syncs the app gateway BackendPools, HttpSettings, Listeners and RoutingRules to the DR.

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


#Requires -Modules Az.Accounts, Az.Network
#requires -Version 5.1

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

$connection = Get-AutomationConnection -Name AzureRunAsConnection

#Wrap authentication in retry logic for transient network failures
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


Set-AzContext -SubscriptionName "XXXXXX"
# Collecting all the properties of APP-Gateway from PRD subscription in a JSON file and converting it to PowerShell object
$AGWPRD = Get-AzApplicationGateway -Name "xxxxxx" -ResourceGroupName "XXXX"

# Collecting all the properties of APP-Gateway from DR subscription and store it in a variable
$APPGW = Get-AzApplicationGateway -Name "XXXXX" -ResourceGroupName "XXXXXXX"

# Get the IPconfig details and store it in the variable
$AGFEIPConfig = Get-AzApplicationGatewayFrontendIPConfig -ApplicationGateway $APPGW


# Get the SSL certificate and store it into a variable
$AGFECert = Get-AzApplicationGatewaySslCertificate -ApplicationGateway $AppGW -Name "XXXXXX"

# Store the Frontend listener Port into a variable
$AGFEPort = Get-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGw -Name "XXXX"

# Store the BackendAddressPools of PRD in array
$BPDR =@()

for ($i=0; $i-lt $APPGW.BackendAddressPools.count; $i++)
{
$BPDR += $AppGw.BackendAddressPools[$i].Name
}


# Store the BackendAddressPools of DR in array
$BPPRD = @()

for ($i=0; $i-lt $AGWPRD.BackendAddressPools.Count; $i++){
$BPPRD += $AGWPRD.BackendAddressPools[$i].Name
}

# Store the HealthProbes of PRD in array
$PBPRD = @()
for ($i=0; $i-lt $AGWPRD.Probes.count; $i++){
$PBPRD += $AGWPRD.Probes[$i].Name
}

# Store the HealthProbes of DR in array
$PBDR = @()
for ($i=0; $i-lt $AppGw.Probes.count; $i++){
$PBDR += $AppGw.Probes[$i].Name
}



# Iterate over PRD Backendpool and check if it already exists in DR
for ($i=0; $i-lt $BPPRD.Count; $i++)
{

# check if the Backend Pool exists or not.
if ($BPDR -Notcontains $BPPRD[$i]){

# Add the Backend Pool name and store it into a variable
Add-AzApplicationGatewayBackendAddressPool -ApplicationGateway $APPGW -Name $BPPRD[$i]
$AGBEP = Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $AppGW -Name $BPPRD[$i]

# collect the information regarding Backend Http settings
for ($j=0; $j-lt $AGWPRD.BackendHttpSettingsCollection.count; $j++){

# If there is a match between Backend pool and Backend http name then we will store that information
if ($AGWPRD.BackendHttpSettingsCollection[$j].Name -match $BPPRD[$i]){
$BEHTTPSsettingsName = $AGWPRD.BackendHttpSettingsCollection[$j].Name
$BEHTTPSsettingsPort = $AGWPRD.BackendHttpSettingsCollection[$j].Port
$BEHTTPSsettingsProtocol = $AGWPRD.BackendHttpSettingsCollection[$j].Protocol
$BEHTTPSsettingsRequestTimeout = $AGWPRD.BackendHttpSettingsCollection[$j].RequestTimeout
}
}

# Configure Backend HTTP Settings and store it into a variable
Add-AzApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW -Name $BEHTTPSsettingsName -Port $BEHTTPSsettingsPort -Protocol $BEHTTPSsettingsProtocol -CookieBasedAffinity Enabled -RequestTimeout $BEHTTPSsettingsRequestTimeout
$AGHTTPS = Get-AzApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW -Name $BEHTTPSsettingsName

# collecting the information regarding Http listener settings
for ($k=0; $k-lt $AGWPRD.HttpListeners.Count; $k++){

# If there is a match between Backend pool and http listener name then we will store that information
if ($AGWPRD.HttpListeners[$k].Name -match $BPPRD[$i]){
$httpsListenerName = $AGWPRD.HttpListeners[$k].Name
$httpsListenerProtocol = $AGWPRD.HttpListeners[$k].Protocol
$httpsHostName = $AGWPRD.HttpListeners[$k].HostName
}
}
# Add a FrontEnd listener on SSL and store it into a variable
Add-AzApplicationGatewayHttpListener -ApplicationGateway $AppGw -Name $httpsListenerName -Protocol $httpsListenerProtocol -FrontendIpConfiguration $AGFEIPConfig -FrontendPort $AGFEPort -SslCertificate $AGFECert -HostName $httpsHostName
$AGListener = Get-AzApplicationGatewayHttpListener -ApplicationGateway $AppGW -Name $httpsListenerName

# collecting the information regarding Routing rules settings
for ($l=0; $l-lt $AGWPRD.RequestRoutingRules.count; $l++){

# If there is a match between Backend pool and routing rule name then we will store that information
if ($AGWPRD.RequestRoutingRules[$l].Name -match $BPPRD[$i]){
$rrName = $AGWPRD.RequestRoutingRules[$l].Name
$rrType = $AGWPRD.RequestRoutingRules[$l].RuleType
}
}
# Tie it all together to create a Routing Rule
Add-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW -Name $rrName -RuleType $rrType -BackendHttpSettings $AGHTTPS -HttpListener $AGListener -BackendAddressPool $AGBEP

}
}

#Adding health probes at the end.
for ($m=0; $m-lt $AGWPRD.Probes.count; $m++){
if ($PBDR -Notcontains $PBPRD[$m]){


Add-AzApplicationGatewayProbeConfig -ApplicationGateway $AppGW -Name $AGWPRD.Probes[$m].Name -Protocol $AGWPRD.Probes[$m].Protocol -HostName $AGWPRD.Probes[$m].Host -Path $AGWPRD.Probes[$m].Path -Interval $AGWPRD.Probes[$m].Interval -Timeout $AGWPRD.Probes[$m].Timeout -UnhealthyThreshold $AGWPRD.Probes[$m].UnhealthyThreshold

}
}

#We need to update the app gateway with new configs without this the changes made to the appgateway won't be saved.
Set-AzApplicationGateway -ApplicationGateway $AppGw