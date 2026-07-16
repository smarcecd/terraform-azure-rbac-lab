# Azure Role-Based Access Control Lab

![Terraform](https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white)
![AzureRM](https://img.shields.io/badge/AzureRM_Provider-3.x-0078D4?logo=microsoftazure&logoColor=white)
![Azure RBAC](https://img.shields.io/badge/Azure-RBAC_Access_Control-0089D6?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-Scripts-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows_Server-Lab_Environment-0078D4?logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Lab_Status-Completed-brightgreen)

---

This lab implements Azure Role-Based Access Control (RBAC) to enforce least privilege on a single virtual machine (FS01). While Lab 1 focused on NTFS permissions inside the VM, this lab controls who can manage the VM itself from Azure.

You will use three user tio assign them each one role, scope them to one VM, validate enforcement, and test each identity using the Azure CLI.

---

# 🔗 Lab Overview

This lab is fully self‑contained. All Terraform and PowerShell files are created locally—no external repo required.

| Component |	Details |
|---|---|
| Purpose | 	Enforce least‑privilege access on VM FS01 using Azure RBAC.| 
| Personas | 	SysAdmin (Owner), SupportTech (VM Contributor), Auditor (Reader).| 
| Scope | 	RBAC applied only to FS01’s resource ID — not the RG, not other VMs.| 
| Terraform Usage | 	Reads Lab 1 resources, assigns RBAC roles, outputs VM + role IDs.| 
| Data Sources | 	azurerm_resource_group, azurerm_virtual_machine (FS01).| 
| Inputs Required | 	Three Azure AD Object IDs (SysAdmin, SupportTech, Auditor).| 
| Scripts Included | 	01-get-object-ids.ps1 (lookup), validate-lab.ps1 (testing).| 
| Validation | 	Azure CLI tests + permission matrix export.| 
| Outcome | 	Clear separation of duties: full control, limited control, view-only.| 


---

## 🎯 Purpose of This Lab

The purpose of this lab is to demonstrate how Azure Role‑Based Access Control (RBAC) enforces least‑privilege access at the Azure control plane. While Lab 1 focused on NTFS permissions inside the VM, this lab shifts to the Azure Resource Manager layer, showing how identity, roles, and scope determine what each persona can do to the VM itself.

You use Terraform to assign three distinct roles to three Azure AD identities, each scoped only to FS01, ensuring tight separation of duties and preventing privilege escalation across the resource group or other machines. The lab concludes with real‑world validation using Azure CLI and PowerShell to confirm that each persona’s permissions behave exactly as intended.

---

# 🧠 Skills Learned

| Skill | Why It Matters |
|---|---|
| RBAC vs NTFS |	Infrastructure vs OS-level permissions — both must be correct. |
| Scoped role assignments |	Narrow scope prevents accidental privilege expansion. |
| Terraform data sources |	Safely reference existing infrastructure without modifying it. |
| Azure AD Object IDs |	Required for RBAC — email addresses are not sufficient. |
| Azure CLI role testing |	Confirms least privilege is enforced, not assumed.|
| Structured validation report | Professional standard for compliance and audits. |

---


## ✅ Prerequisites

Before starting, ensure the following are ready:

- [ ] [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated (`az login`)
- [ ] [Terraform](https://developer.hashicorp.com/terraform/downloads) **v1.3+** installed
- [ ] Active Azure subscription with permissions to create resources
- [ ] [Git for Windows](https://git-scm.com) 
- [ ] Have the infrastructe build on: [🗂️ Lab 1 - NTFS File Server Lab (Azure + Terraform)](https://github.com/smarcecd/ntfs-file-server-lab-azure/blob/main/README.md)
- [ ] Three Azure AD user accounts with the UPN in hand, to simulate real‑world RBAC personas: SysAdmin — Owner, SupportTech — VM Contributor, Auditor — Reader.


To learn how to Install Terraform and connect it to your Azure susbscription, please check on: 

[Terraform installation and connection to Azure](https://github.com/smarcecd/Terraform-Automation---Azure-Active-Directory-Domain-Controller/blob/main/Terraform%20Install%20and%20Azure%20connection.md)


---

# 📂 Project Structure

```bash
rbac-lab-terraform/
├── backend.tf
├── versions.tf
├── variables.tf
├── data.tf
├── rbac.tf
├── outputs.tf
├── terraform.tfvars.example
├── terraform.tfvars        # never commit
├── .gitignore
├── validate-lab.ps1
└── scripts/
    └── 01-get-object-ids.ps1
```

---

# 🔧 Key Components

**Terraform Files**
backend.tf — Uses Lab 1’s storage account with a new state key.

variables.tf — Three Object ID inputs (no defaults for safety).

data.tf — Reads Lab 1’s resource group and FS01 VM.

rbac.tf — Creates three role assignments scoped to FS01 only.

outputs.tf — Exposes VM ID and role assignment IDs.

**PowerShell Scripts**
01-get-object-ids.ps1 — Converts user emails → Azure AD Object IDs.

validate-lab.ps1 — Confirms RBAC propagation and exports a permission matrix.

---

# 👥 Roles Assigned

| Persona | Role | Permissions| 
|---|---|---|
| SysAdmin | 	Owner | Full control, including RBAC management | 
| SupportTech | Virtual Machine Contributor | 	Start/stop/restart only | 
| Auditor | Reader | 	View-only access| 


---

## 🚀 Deployment Guide


Watch me doing this lab here:

[![lab22](https://github.com/user-attachments/assets/6db74990-5e9f-4ef6-b85b-84991a7985e3)](https://www.loom.com/share/fbb792b5c8dc4739b760b835264e31f1)

---

### Step 1 — Clone This Repository to Your Project Folder

Create a dedicated project folder with all Terraform files stored in the root directory. Place all PowerShell automation scripts inside a scripts/ subfolder. The configure-lab.ps1 orchestrator relies on this exact structure and calls each script using relative paths, so the layout must remain unchanged. 

To download this lab to your computer, run the following command in your terminal or PowerShell:

```powershell
git clone https://github.com/smarcecd/terraform-azure-rbac-lab.git
```

This will create a folder named: **terraform-azure-rbac-lab** . Then navigate into it:

```powershell
cd terraform-azure-rbac-lab
```
You now have the full project locally and can begin exploring or deploying the Terraform lab.

---

### Step 2 — Prepare the Identities for RBAC Testing

As mentioned on the prerequisits, Three Azure AD user accounts to simulate real‑world RBAC personas: SysAdmin — Owner, SupportTech — VM Contributor, Auditor — Reader.

You will need the **User principal name** or **UPN** of these three users. Once you have it, you can get the **Object ID** from the 01-get-object-ids.ps1 script.
 
```powershell
.\scripts\01-get-object-ids.ps1
#Paste results into terraform.tfvars.
```

Alternatively, you can retrieve Object IDs manually from the **Azure Portal**:
1. Search and open **Microsoft Entra ID**
2. Select **Manage** → **Users**
3. Click each user
4. On the Overview page, copy the **Object ID**

---

### Step 3 — Configure Variables

Now update the configuration:
- Open terraform.tfvars.example and and replace the placeholder values (REPLACE_WITH_SYSADMIN_OBJECT_ID) with the corresponding **Object IDs** for SysAdmin, SupportTech, and Auditor, the ones you retrieved in Step 2.
- Ensure resource_group_name = "RG-FileServerLab" matches **Lab 1 NTFS File Server Lab (Azure + Terraform)** exactly.
- Ensure vm_name = "FS01" matches Lab 1 exactly.

Finally:  
Open backend.tf and replace REPLACE_WITH_YOUR_LAB1_STORAGE_ACCOUNT_NAME with the actual storage account name created in **Lab 1 NTFS File Server Lab (Azure + Terraform)**.

Then, Copy the example file into an active tfvars file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

---

### Step 4 — Initialize & Apply

- Authenticate your local machine to your Admin Azure account
```powershell
az login
```
- Deploy and validate: 
```powershell
terraform init
```

```powershell
terraform plan
```

```powershell
terraform apply
```
---

### Step 5 - Run the Validation Script

This step verifies that the RBAC roles deployed in the lab are correctly applied to the FS01 virtual machine. The script retrieves the VM’s resource ID, checks the live role assignments at the VM scope, prints a permission matrix, and exports a validation report (RBAC_Lab_Report.txt). A successful run should show ALL PASS.

Run the script:

```powershell
.\validate-lab.ps1
```    

A successful validation will display:  
Overall: ALL PASS

And a report will be generated:
RBAC_Lab_Report.txt

---

### Step 6 — Testing Each Persona

[![lab2-2](https://github.com/user-attachments/assets/df891de1-6723-4e89-a897-c61f4c434e55)](https://www.loom.com/share/9b96fa12a7b043a4adb58b75d674a29f)

**Auditor (Reader)** 

Log in as your Auditor test account
```powershell
az login   
```

✔ Can view VM details  
```powershell
az vm show -g RG-FileServerLab -n FS01 --query "{name:name,size:hardwareProfile.vmSize}"
# Expected: SUCCEEDS — Reader can view VM details
  
```

✘ Cannot stop/start VM  
```powershell
az vm stop -g RG-FileServerLab -n FS01
# Expected: FAILS — AuthorizationFailed
# This failure confirms the Reader role is working. Auditor cannot stop VMs.
```


**SupportTech (VM Contributor)**  

Log in as your SupportTech test account
```powershell
az login   
```

✔ Can start/stop/restart VM  
```powershell
az vm start -g RG-FileServerLab -n FS01
# Expected: SUCCEEDS — VM Contributor can start VMs  
```

✘ Cannot view or modify RBAC  
```powershell
az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# Expected: FAILS — AuthorizationFailed
# SupportTech cannot view or manage RBAC assignments. 
```


**SysAdmin (Owner)**  

Log in as your SysAdmin test account
```powershell
az login   
```

✔ Full control 
```powershell
az vm show -g RG-FileServerLab -n FS01 --query "{name:name}"
# Expected: SUCCEEDS
```

✔ Can manage RBAC  
```powershell
az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# Expected: SUCCEEDS — Owner can view and manage RBAC assignments
```


---

# 🧹 Teardown Options

- Option A — Remove RBAC Only

```bash
terraform destroy
```

- Option B — Full Cleanup
```bash
terraform destroy
az group delete -n RG-FileServerLab --yes --no-wait
```

---

# 🐛 Troubleshooting

|Issue | Cause | Fix |
|---|---|---|
| Principal not found |	Wrong Object ID	| Re-run lookup script |
| Resource group not found |	Lab 1 missing	| Deploy Lab 1 first |
| RBAC propagation delay |	Azure backend	| Wait 5–10 minutes |
| Plan shows >3 resources |	Name mismatch	| Check capitalization |


---

# 📘 Summary

This lab demonstrates real-world RBAC implementation using Terraform, Azure AD, and the Azure CLI. You enforce least privilege, validate permissions, and produce an auditable report — exactly how enterprise cloud teams manage access securely.	
