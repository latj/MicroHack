# Walkthrough Challenge 1 - Prerequisites and Landing Zone

Duration: 30 minutes

## Prerequisites

- Please ensure that you successfully verified the [General prerequisites](../../Readme.md#general-prerequisites) before continuing with this challenge.
- Azure Cloud Shell together with Terraform are the tools of choice for deploying the MicroHack.

### **Task 1: Deploy the Landing Zone for the MicroHack**

- Open the [Azure Portal](https://portal.azure.com) and login using a user account with at least Contributor permissions on a Azure Subscription. Start the Azure Cloud Shell from the Menu bar on the top.
- If you prefer a full-screen shell then go to [Cloud Shell](https://shell.azure.com)

![image](./img/CS1.png)

- If this is the first time that Cloud Shell is beeing started, create a storage account by selecting *Bash* and clicking on *Create storage*. Wait until the storage account has been created.

![image](./img/CS1-1.png)

![image](./img/CS2.png)

- Make sure to select *Bash*.

![image](./img/CS3.png)

- Clone the MicroHack Github repository using command:

```
git clone https://github.com/latj/MicroHack.git
```

- Change into to Migrate & Modernize Microhack directory of the cloned repository using command:

```
cd MicroHack/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources-tf
```

- Terraform requires a subscription ID to operate. Use the Azure Portal to find your subscription ID, or run the command:

```
az account list -o table
```

- Once you have your subscription ID, set Terraform variable ARM_SUBSCRIPTION_ID as follows:

```
export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

- You are now ready to deploy the MicroHack resources. Run commands:

```
terraform init
```
```
terraform apply
```

- You will be prompted to enter an administrator password. Choose a password with sufficient complexity. The password will be stored in a key vault, so you don't have to remember it.

```
var.admin_password
  The administrator password for virtual machines

  Enter a value: 
```

- You are shown the list of resources that will be created. Answer `Yes` and continue.

```
Plan: 44 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

- Wait for the deployment to finish. You can view the deployment from the Azure portal by selecting the Azure Subscription and clicking on *Deployments* from the navigation pane on the left.

![image](./img/CS7.png)

> [!NOTE]
> Please note that the deployment may take up to 15 minutes.

### **Task 2: Verify the deployed resources**
The Terraform deployment should have created the following resources:

- Resource group `microhack-groupX-onprem-rg` containing:
    + Virtual network *onprem-vnet*
    + Windows VM *winweb1* with an installed web server
    + Red Hat Linux VM *lnxweb1* with an installed web server
    + Public load balancer *onprem-lb* with a configured backend pool containing *winweb1* and *lnxweb1*
    + Azure Bastion *onprem-bastion*
    + Azure key vault *microhack-groupX-kv* containing the administrator password selected during deployment
   
- Resource group `microhack-groupX-azure-rg` containing:
    + Virtual network *azure-vnet*
    + Azure Bastion *azure-bastion*

The deployed architecture looks like following diagram:
![image](./img/Challenge-1.jpg)

### **Task 3: Verify Web Server availability**

- Open the on-premises resource group
- Select the load balancer
- Navigate to *Frontend IP configuration* under *Settings* section on the left
- Note and copy public IP address of *LoadBalancerFrontEnd*
- Open web browser and navigate to `http://<copied_IP_address>`
- A simple website containing the server name of the frontend1 or frontend2 VM should be displayed

You successfully completed challenge 1! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-2/solution.md)
