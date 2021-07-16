# Automatically deploy Azure Application Gateway using PowerShell scripts in Disaster Recovery region when disaster occurs 

Assumptions: These scripts work perfectly fine with the following assumptions.
1. Already App gateway is running in the Production and there is backup App gateway in a failover region in a passive mode(which is not live).
2. Service principal is assigned with right privileges to access the configurations for App gateway, Azure storage account and Azure Automation Accounts.
3. These scripts are run through Azure Automation Accounts using RunAsConnection. So, make sure you have Azure Account with RunAsConnection.
4. These scripts assume right Azure modules are imported into modules gallery.

# How it works?
Three step process to deploy Azure Application Gateway in DR region at the time of disaster.
1. First step is to Synchronize the AppGateway configurations from Production environment(which is live) to the failover region(which is in passive mode). **APPGWConfig.ps1** script is run through Azure Automation runbook on weekly or daily basis as per the business requirements.
2. Second step is to get the VM names of backendaddress pools using their IP addresses in production environment and store it as a file in a blob storage. **APPGW-IP-VM.ps1** is run through Azure Automation runbook on weekly or daily basis as per the business requirements.
3. Third step is the final step, When disaster occurs in production region then we need to run the final script which is **APPGW-VM-IP.ps1** to add the IP addresses to the AppGateway to finally failover to the DR region.

Hope this helps.

