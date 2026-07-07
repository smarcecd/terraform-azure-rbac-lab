# Azure Role-Based Access Control Lab

![Terraform](https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white)
![AzureRM](https://img.shields.io/badge/AzureRM_Provider-3.x-0078D4?logo=microsoftazure&logoColor=white)
![Azure RBAC](https://img.shields.io/badge/Azure-RBAC_Access_Control-0089D6?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-Scripts-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows_Server-Lab_Environment-0078D4?logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Lab_Status-Completed-brightgreen)

---

# 📌 Overview

This lab implements Azure Role-Based Access Control (RBAC) to enforce least privilege on a single virtual machine (FS01). While Lab 1 focused on NTFS permissions inside the VM, this lab controls who can manage the VM itself from Azure.

You will create three personas, assign three roles, scope them to one VM, validate enforcement, and test each identity using the Azure CLI.

---

# 🎯 Business Problem

Organizations need strict separation of duties:
- A SysAdmin must fully manage a VM, including RBAC.
- A Support Technician must restart a VM but never delete or reconfigure it.
- An Auditor must view VM details but perform no actions.
- Azure RBAC solves this by assigning precise permissions at the resource level.

---

# 🏗 Architecture

RBAC operates at the Azure Resource Manager control plane, separate from NTFS.
All role assignments are scoped to FS01’s resource ID only, ensuring:

- No permissions apply to DC01 or CLIENT01
- No permissions apply to the resource group
- Blast radius is minimized

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

# 🚀 Deployment Steps

**1.** Verify Prerequisites

```bash
terraform -version   # >= 1.5.0
az version
az account show
```

**2.** Create Project Folder

```powershell
New-Item -ItemType Directory "$HOME\rbac-lab-terraform"
cd "$HOME\rbac-lab-terraform"
New-Item -ItemType Directory "scripts"
```

**3.** Generate Object IDs

```powershell
.\scripts\01-get-object-ids.ps1
Paste results into terraform.tfvars.
```

**4.** Initialize & Apply

```bash
terraform init
terraform plan   # should show exactly 3 resources
terraform apply
```

**5.** Validate RBAC

```powershell
.\validate-lab.ps1
Exports: RBAC_Lab_Report.txt
```

---

# 🧪 Testing Each Persona

**Auditor (Reader)**
✔ Can view VM details
✘ Cannot stop/start VM

**SupportTech (VM Contributor)**
✔ Can start/stop/restart VM
✘ Cannot view or modify RBAC

**SysAdmin (Owner)**
✔ Full control
✔ Can manage RBAC

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
