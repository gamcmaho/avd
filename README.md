# Bicep deploy of AVD using Win 11 Ent Multi-Session
Used Bicep as a Domain Specific Language (DSL) to deploy a traditional Hub and Spoke architecture.  Solution secured using Azure Firewall, Azure Bastion and Private Link.  Used Private Endpoint to connect to Azure Files storage in conjunction with FSLogix Profile Containers.  In turn, supporting the use of Windows 11 Ent Multi-Session.  Also showcased the use of Azure Compute Gallery to store multiple replicas of Golden images across Azure regions.  
<br>
Note. The deployment assumes an empty Resource Group and provisions a test Windows Server AD, handles domain join and registration of new Session Hosts.
<br><br><br>
<img src="https://github.com/gamcmaho/avd/blob/main/BicepAvdHubSpoke.jpg">
<br><br>
<h3>First generate a Token Expiration (now + 24 hours)</h3>
Using PowerShell run,<br><br>
$((get-date).ToUniversalTime().AddHours(24).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
<br><br>
Note.  The maximum life time of a token is 30 days.
<br><br>
<h3>Git Clone the repo to your local device</h3>
git clone https://github.com/gamcmaho/avd.git
<br><br>
Create a new Resource Group in your Subscription for the AVD deployment
<br><br>
az login<br>
az account set -s "&ltsubscription name&gt"<br>
az group create --name "&ltresource group name&gt" --location "&ltlocation&gt"<br><br>
<h3>Use existing Azure Compute Gallery, or deploy a new gallery</h3>
To deploy a new gallery:
<br><br>
After cloning the repo, change to the "gallery" subdirectory of the "avd" directory<br>
Modify the gallery "parameters.json" providing values for:
<br><br>
location<br>
azure_compute_gallery_name
<br><br>
Note.  The Azure Compute Gallery name should be unique
<br><br><br>
Then deploy a new Azure Compute Gallery by running:<br><br>
az deployment group create -g "&ltresource group name&gt" --template-file "gallery.bicep" --parameters "parameters.json"
<br><br>
<h3>Use existing Master image in your Azure Compute Gallery, or capture a new image</h3>
To prepare and capture a new image:
<br><br>
Deploy a Windows 11 Ent Multi-Session VM from the Azure Marketplace, e.g. win11-22h2-avd<br>
Install the latest Windows updates<br>
Depending on the Marketplace image used, FSLogix may already be installed.  If not, please install the latest version<br>
Add FSLogix items to the registry, remembering to update the storage account name below
<br><br>
$regPath = "HKLM:\SOFTWARE\FSLogix\Profiles"<br>
New-ItemProperty -Path $regPath -Name Enabled -PropertyType DWORD -Value 1 -Force<br>
New-ItemProperty -Path $regPath -Name VHDLocations -PropertyType MultiString -Value \\&ltstorage-account-name&gt.file.core.windows.net\profiles -Force
<br><br>
Sysprep and Generalise by running %WINDIR%\system32\sysprep\sysprep.exe /generalize /shutdown /oobe<br>
From the virtual machine blade, once stopped, capture an image and store in your Azure Compute Gallery<br>
Then make a note of the Image URL for later reference.  See example Image URL below:
<br><br>
/subscriptions/&ltsubscription id&gt/resourceGroups/&ltresource group name&gt/providers/Microsoft.Compute/galleries/&ltAzure compute gallery name&gt/images/&ltimage name&gt
<br><br>
<h3>Deploying the AVD solution</h3>
Change directory to "avd" and modify the main "parameters.json" providing values for:<br><br>
location<br>
storage_account_name<br>
vm_gallery_image_id<br>
token_expiration_time<br>
total_instances<br>
vm_size
<br><br>
Note.  The storage account name needs to be globally unique and the maximum life time of a token is 30 days.
<br><br><br>
Update the resource group name below and deploy.  Note.  The BICEP deployment typically takes around 20 minutes.
<br><br>
az deployment group create -g "&ltresource group name&gt" --template-file "main.bicep" --parameters "parameters.json"
<br><br>
<h3>Configure ADDS and DNS</h3>
Azure Bastion to vm-dc<br>
Create a new domain account, member of Domain Admin and Enterprise Admin<br>
Create new Security Groups and Users to test Desktop Application Group (DAG) and Remote Application Group (RAG) access<br>
Configure DNS by adding a Conditional Forwarder file.core.windows.net -> 168.63.129.16 (Azure Recursive Resolver)<br>
For testing purposes, deploy AAD Connect Sync on vm-dc using Password Hash Synchronisation through to AAD.<br>
https://www.microsoft.com/en-us/download/details.aspx?id=47594
<br><br>
Note.  AVD requires Hybrid identities originating from Windows Server AD.<br>
<br><br>
<h3>Prepare your Azure Files share for FSLogix Profile Containers</h3>
Using the Azure Portal, grant Data RBAC "Storage File Data SMB Share Elevated Contributor" to your Domain Admin/ Enterprise Admin user scoped to your Storage Account<br>
At the same time, grant Data RBAC "Storage File Data SMB Share Contributor" to your test Security Groups scoped to your Storage Account<br>
Azure Bastion to vm-test and sign-in using your Domain Admin/ Enterprise Admin user, then follow Steps 1 through to 4 below:
<br><br>
Step 1: Enable Active Directory authentication<br>
https://docs.microsoft.com/azure/storage/files/storage-files-identity-ad-ds-enable
<br><br>
Step 2: Enable share-level permissions<br>
https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-ad-ds-assign-permissions
<br><br>
Step 3: Assign directory/ file-level permissions<br>
https://docs.microsoft.com/azure/storage/files/storage-files-identity-ad-ds-configure-permissions
<br><br>
Note.  Configure Windows ACLs with Windows File Explorer.
<br><br><br>
Step 4: Mount Azure Files share using AD credentials<br>
https://docs.microsoft.com/azure/storage/files/storage-files-identity-ad-ds-mount-file-share
<br><br>
Note. For testing purposes, run:<br><br>
SystemPropertiesRemote on vm-test as Domain Admin/ Enterprise Admin user<br>
Add test users to allow remote connections to the computer<br>
Logoff, then sign into vm-test as a test user using Azure Bastion<br>
Use File Explorer to access \\&ltstorage-account-name&gt.file.core.windows.net\profiles (update the storage account name)<br>
Confirm the test user is able to access the Azure Files share using their Data RBAC role assignment
<br><br>
<h3>Grant DAG and RAG access within AVD</h3>
Use Azure Portal and navigate to AVD -> Host Pools -> Session Hosts and confirm Domain Join and Health check status is healthy<br>
Navigate to AVD -> Application Groups -> dag-avd-> Assignments and add your first Security Group<br>
Then, confirm that your test user member of this security group can access a full desktop using the AVD Web Client<br>
https://client.wvd.microsoft.com/arm/webclient/index.html
<br><br>
Next, navigate to AVD -> Application Groups ->  rag-avd<br>
Add "Wordpad" as an Application and assign to your second Security Group<br>
Then, confirm your test user member of this security group can access "Wordpad" using the AVD Web Client<br>
https://client.wvd.microsoft.com/arm/webclient/index.html
<br><br>
<h3>From a security standpoint, enforce MFA for your new users in AAD</h3>
Using the Azure Portal, navigate to AAD -> Users -> Per-user MFA<br>
For each user, Enforce the use of MFA<br>
On first logon, follow instructions using the Microsoft Authenticator app
<br><br>
<h3>Congratulations, you're up and running with AVD!</h3>
