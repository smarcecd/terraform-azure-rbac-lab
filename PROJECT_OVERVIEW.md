# PROJECT OVERVIEW — Azure RBAC Lab

---

## Table of Contents

1. [Project Purpose](#1-project-purpose)
2. [Learning Objectives](#2-learning-objectives)
3. [Prerequisites](#3-prerequisites)
4. [Architecture at a Glance](#4-architecture-at-a-glance)
5. [Personas & What They Demonstrate](#5-personas--what-they-demonstrate)
6. [Repository Structure](#6-repository-structure)
7. [Quick Start](#7-quick-start)
8. [Terraform Usage](#8-terraform-usage)
9. [Validation & Testing](#9-validation--testing)
10. [Key Concepts Reinforced](#10-key-concepts-reinforced)
11. [Clean Up](#11-clean-up)
12. [Contributing](#12-contributing)
13. [References](#13-references)

---

## 1. Project Purpose

This project is a **hands-on Azure Role-Based Access Control (RBAC) lab** designed to
demonstrate real-world identity and access management patterns in Microsoft Azure. It
provisions a realistic multi-tier cloud environment entirely with Terraform and populates
it with seven distinct personas, each assigned only the permissions required for their role.

The lab is built around three core principles:

- **Least Privilege** — every persona has exactly the access they need and nothing more
- **Scope Precision** — role assignments are applied at the tightest appropriate scope
  (resource, resource group, or subscription)
- **Repeatability** — the entire environment can be deployed, validated, torn down, and
  rebuilt from a single `terraform apply`

Whether you are studying for an Azure certification, onboarding engineers to IAM concepts,
or building a reference implementation for your organization's RBAC governance model, this
lab provides a concrete, inspectable, and fully automated baseline.

---

## 2. Learning Objectives

After completing this lab you will be able to:

- [ ] Explain the difference between Azure **control-plane** (ARM) and **data-plane** RBAC
- [ ] Assign Azure built-in roles at the correct scope (management group, subscription,
      resource group, or individual resource)
- [ ] Distinguish between **additive permissions** and **deny assignments**
- [ ] Identify when a Contributor on a Resource Group does **not** have data-plane access
      to Storage blobs, SQL databases, or Key Vault secrets
- [ ] Validate effective permissions programmatically using the Azure CLI
- [ ] Manage all RBAC assignments as code with Terraform's `azurerm_role_assignment`
- [ ] Trace an authorization decision through Azure's ARM evaluation pipeline
- [ ] Design a multi-persona RBAC model that covers audit, network, dev, data, and
      security boundaries independently

---

## 3. Prerequisites

### Required Tooling

| Tool | Minimum Version | Purpose |
|---|---|---|
| Terraform | `>= 1.6` | Infrastructure provisioning |
| Azure CLI | `>= 2.55` | Authentication & validation |
| Git | any | Source control |
| `bash` or WSL | any | Running the validation script |

### Azure Requirements

| Requirement | Notes |
|---|---|
| Active Azure Subscription | Free tier works; some resources require standard SKU |
| **Owner** role on the Subscription | Required to create role assignments |
| **Azure AD / Entra ID** permissions | Ability to create users and groups (`User Administrator` or `Global Administrator`) |
| Azure CLI authenticated | Run `az login` and `az account set --subscription <id>` before applying |

### Optional but Recommended

- VS Code with the HashiCorp Terraform extension
- Azure Policy familiarity (lab references Policy but does not require it to be active)

---

## 4. Architecture at a Glance

The lab deploys resources across **four Resource Groups** under a single Subscription,
organized by function:

```text
Subscription
├── rg-rbac-admin    →  Key Vault · Log Analytics · Audit Storage
├── rg-rbac-dev      →  App Service Plan · App Service · App Insights
├── rg-rbac-data     →  SQL Server · SQL Database · Data Storage
└── rg-rbac-network  →  Virtual Network · Subnets · NSG
```


All secrets are centralized in Key Vault. All diagnostic logs flow to Log Analytics.
Network segmentation isolates the app tier (`snet-app`) from the data tier (`snet-data`).

> 📄 Full diagrams, scope maps, control-plane flow, and resource relationship maps
> are in [`ARCHITECTURE_DIAGRAM.md`](./ARCHITECTURE_DIAGRAM.md).

---

## 5. Personas & What They Demonstrate

The lab creates **seven personas**, each illustrating a different RBAC pattern:

---

### 🔑 Lab Admin
**Role:** `Owner` @ Subscription
**Demonstrates:** Unrestricted control including role assignment delegation. This is the
identity used to run Terraform and bootstrap all other assignments. In production, Owner
should be reserved for break-glass accounts and protected by PIM.

---

### 💻 Developer
**Roles:** `Contributor` @ `rg-rbac-dev` · `Reader` @ `rg-rbac-network`
**Demonstrates:** Scoped write access to a single resource group, read-only visibility
into the network layer, and a hard wall against touching data, secrets, or other RGs.

---

### 📊 Data Engineer
**Roles:** `Storage Blob Data Contributor` @ `st-rbac-data` · `SQL DB Contributor` @ `sqldb-rbac`
**Demonstrates:** Pure **data-plane** role assignment. The persona cannot manage the
Storage Account or SQL Server at the ARM level — only the data inside them. Critically
illustrates that `Contributor` on an RG does **not** grant blob or SQL data access.

---

### 🔍 Security Auditor
**Roles:** `Security Reader` @ Subscription · `Reader` @ Subscription
**Demonstrates:** Subscription-wide read visibility for compliance purposes, with zero
ability to modify anything. Validates that auditors can see all resources and security
assessments without touching workloads.

---

### 🌐 Network Engineer
**Role:** `Network Contributor` @ `rg-rbac-network`
**Demonstrates:** Granular built-in role scoped tightly to a single RG. Can manage
VNets, subnets, and NSGs but has no access to compute, data, or secrets.

---

### 👁 Read-Only User
**Role:** `Reader` @ `rg-rbac-dev`
**Demonstrates:** The simplest least-privilege pattern — view-only access to one RG.
Useful for stakeholders, on-call reviewers, or junior team members who need visibility
without write risk.

---

### 🗝 Key Vault Admin
**Role:** `Key Vault Administrator` @ `kv-rbac-lab`
**Demonstrates:** Resource-level data-plane role scoped to a single Key Vault. Can manage
secrets, keys, and certificates inside that vault but has no ARM-level access to delete
or reconfigure the vault itself.

---

## 6. Repository Structure

```text
azure-rbac-lab/
│
├── README.md                    # High-level entry point and lab overview
├── PROJECT_OVERVIEW.md          # This file — goals, setup, usage, and concepts
├── ARCHITECTURE_DIAGRAM.md      # ASCII diagrams: hierarchy, flows, relationships
│
├── terraform/
│   ├── main.tf                  # Root module
│   ├── variables.tf             # All input variables
│   ├── outputs.tf               # Exported resource IDs and assignment IDs
│   ├── providers.tf             # azurerm + azuread provider config
│   ├── terraform.tfvars         # Your values — never commit this file
│   ├── terraform.tfvars.example # Safe template to commit
│   │
│   └── modules/
│       ├── resource-groups/     # RG definitions with tagging
│       ├── networking/          # VNet, subnets, NSG
│       ├── compute/             # App Service Plan + App Service
│       ├── data/                # SQL Server, SQL DB, Storage (data)
│       ├── security/            # Key Vault, Log Analytics, audit Storage
│       └── rbac/                # Azure AD identities + role assignments
│           └── role_assignments/
│               ├── lab_admin.tf
│               ├── developer.tf
│               ├── data_engineer.tf
│               ├── security_auditor.tf
│               ├── network_engineer.tf
│               ├── readonly_user.tf
│               └── kv_admin.tf
│
└── tests/
├── validate_rbac.sh          # Automated permission validation script
└── expected_permissions.json # Canonical allow/deny truth table
```


---

## 7. Quick Start

### Step 1 — Clone the repo

```bash
git clone https://github.com/<your-org>/azure-rbac-lab.git
cd azure-rbac-lab
```

### Step 2 — Authenticate to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Step 3 — Configure variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit terraform.tfvars and fill in at minimum:

```bash
subscription_id = "<your-subscription-id>"
tenant_id       = "<your-tenant-id>"
location        = "eastus"   # or your preferred region
prefix          = "rbac"     # resource naming prefix
```

### Step 4 — Initialize Terraform
```bash
cd terraform
terraform init
```

### Step 5 — Preview the plan

```bash
terraform plan -out=tfplan
```

Review the output. You should see resources across all four resource groups and role
assignments for every persona.

### Step 6 — Apply
```bash
terraform apply tfplan
```

Deployment typically takes 5–10 minutes.

### Step 7 — Run validation
```bash
cd ../tests
chmod +x validate_rbac.sh
./validate_rbac.sh
```
A passing run prints a summary with all ALLOW/DENY tests verified per persona.

---

## 8. Terraform Usage

**Providers**
```bash
# providers.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}
```

**Key Variables**

Variable	Type	Description
subscription_id	string	Target Azure subscription
tenant_id	string	Azure AD tenant
location	string	Primary Azure region (e.g. eastus)
prefix	string	Naming prefix applied to all resources
tags	map(string)	Common tags applied to all resources


**Key Outputs**

Output	Description
kv_id	Resource ID of the Key Vault
log_analytics_workspace_id	Resource ID of the Log Analytics Workspace
vnet_id	Resource ID of the Virtual Network
role_assignment_ids	Map of persona → role assignment resource IDs


**State Management**
For team use, configure a remote backend (Azure Storage recommended):
```bash
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "rbac-lab.terraform.tfstate"
  }
}
```


---

## 9.Validation & Testing
The validation script (tests/validate_rbac.sh) logs in as each persona's service
principal and tests a curated set of Azure CLI commands against the deployed environment.

What it checks
Test Type	Expected Result	Failure Meaning
ALLOW	CLI exits with code 0	Role assignment missing or incorrectly scoped
DENY	CLI exits with non-zero (HTTP 403)	Persona is over-permissioned — least-privilege violated

**Running a single persona**
```bash
./validate_rbac.sh --persona developer
```

**Sample output**

```text
========================================
  Azure RBAC Lab — Validation Report
========================================

[Developer]
  ✅ PASS  webapp list (rg-rbac-dev)
  ✅ PASS  webapp restart (app-rbac-dev)
  ✅ PASS  network vnet list (rg-rbac-network) — Reader
  ✅ PASS  DENY keyvault secret list (403 confirmed)
  ✅ PASS  DENY sql server list (403 confirmed)

[Data Engineer]
  ✅ PASS  storage blob upload (st-rbac-data)
  ✅ PASS  sql db show (sqldb-rbac)
  ✅ PASS  DENY storage blob upload (st-rbac-audit) — 403 confirmed

----------------------------------------
  Results:  12 passed · 0 failed
  Status:   ✅ ALL CHECKS PASSED
========================================
```

**Manual spot-check**

```bash
az role assignment list \
  --assignee "<object-id-or-upn>" \
  --include-inherited \
  --output table

```
---

## 10. Key Concepts Reinforced
Control Plane vs. Data Plane
Layer	Governed by	Example operation
Control plane	Azure Resource Manager (ARM)	az webapp create, az storage account show
Data plane	Service-level RBAC	az storage blob upload, az keyvault secret get


A Contributor role on a Resource Group grants ARM control, but does not grant
read or write access to blob contents, SQL rows, or Key Vault secrets. Data-plane
access requires separate, explicitly assigned data-plane roles.

**Scope Inheritance** 
```text
Subscription   ──────────────► inherited by all child RGs and resources
Resource Group ─────────────► inherited by all resources within it
Resource       ─────────────► applies only to that resource
```

**Additive vs. Deny**
Multiple roles on the same principal are additive — the effective permission set
is the union of all granted permissions.

Deny assignments are evaluated first and override any grant, regardless of how
many roles grant that permission.

**Role Assignment Propagation**
After terraform apply creates an azurerm_role_assignment, ARM replicates it
globally. Allow up to 2 minutes before the assignment is consistently enforced
across all Azure services. The validation script includes a configurable wait for this.

---

## 11. Clean Up

To destroy all lab resources and avoid ongoing charges:
```bash
cd terraform
terraform destroy
```

Type yes when prompted. This removes:

- All four Resource Groups and every resource inside them
- All Azure AD users and groups created by the lab
- All role assignments

⚠️ Soft-delete: Key Vault uses soft-delete by default (90-day retention).
If you re-run the lab in the same tenant, purge the vault first:

```bash
az keyvault purge --name kv-rbac-lab --location eastus
```
