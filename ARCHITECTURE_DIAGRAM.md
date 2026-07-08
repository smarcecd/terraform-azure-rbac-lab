# ARCHITECTURE_DIAGRAM.md — Azure RBAC Lab

---

## Table of Contents

1. [Lab Overview](#1-lab-overview)
2. [Azure Resource Hierarchy](#2-azure-resource-hierarchy)
3. [Persona & Role Matrix](#3-persona--role-matrix)
4. [Role Scope Diagram](#4-role-scope-diagram)
5. [Control Plane Flow](#5-control-plane-flow)
6. [Resource Relationship Map](#6-resource-relationship-map)
7. [Terraform Module Structure](#7-terraform-module-structure)
8. [RBAC Assignment Flow](#8-rbac-assignment-flow)
9. [Validation Paths](#9-validation-paths)
10. [Security Boundaries](#10-security-boundaries)
11. [Quick Reference: Built-In Role IDs](#11-quick-reference-built-in-role-ids)

---

## 1. Lab Overview

This lab demonstrates Azure Role-Based Access Control (RBAC) across multiple personas,
resource scopes, and management layers. Terraform provisions all infrastructure, identities,
and role assignments, enabling repeatable, auditable RBAC validation.

```text
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE RBAC LAB                           │
│                                                                 │
│   Goal : Demonstrate least-privilege access across personas     │
│   IaC  : Terraform  (azurerm + azuread providers)              │
│   Scope: Management Group → Subscription → RG → Resource        │
└─────────────────────────────────────────────────────────────────┘
```


---

## 2. Azure Resource Hierarchy

The RBAC scope chain follows Azure's native management hierarchy.
Role assignments at a higher scope are **inherited** by all child scopes.

```text
Tenant (Azure AD / Entra ID)
│
└── Management Group: lab-mg
│   Scope: /providers/Microsoft.Management/managementGroups/lab-mg
│
└── Management Group: rbac-lab
│   Scope: /providers/Microsoft.Management/managementGroups/rbac-lab
│
└── Subscription
Scope: /subscriptions/<subscription-id>
│
├── Resource Group: rg-rbac-admin
│   ├── Key Vault            (kv-rbac-lab)
│   ├── Storage Account      (st-rbac-audit)
│   └── Log Analytics Workspace
│
├── Resource Group: rg-rbac-dev
│   ├── App Service Plan
│   ├── App Service          (app-rbac-dev)
│   └── Application Insights
│
├── Resource Group: rg-rbac-data
│   ├── Azure SQL Server     (sql-rbac-lab)
│   ├── Azure SQL Database   (sqldb-rbac)
│   └── Storage Account      (st-rbac-data)
│
└── Resource Group: rg-rbac-network
├── Virtual Network      (vnet-rbac-lab)
├── Subnet               (snet-app   10.0.1.0/24)
├── Subnet               (snet-data  10.0.2.0/24)
└── Network Security Group (nsg-rbac-lab)
```


---

## 3. Persona & Role Matrix

Each persona maps to one or more Azure built-in (or custom) roles scoped to the
appropriate level.

```text
╔══════════════════╦══════════════════════════════╦══════════════════════╦════════════════════════════╗
║ Persona          ║ Azure Role(s)                ║ Scope                ║ Access Summary             ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Lab Admin        ║ Owner                        ║ Subscription         ║ Full control; assigns      ║
║                  ║                              ║                      ║ roles to all personas      ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Developer        ║ Contributor                  ║ rg-rbac-dev          ║ Deploy & manage app        ║
║                  ║ Reader                       ║ rg-rbac-network      ║ resources; read-only on    ║
║                  ║                              ║                      ║ network RG                 ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Data Engineer    ║ Storage Blob Data Contributor║ st-rbac-data         ║ Full blob access;          ║
║                  ║ SQL DB Contributor           ║ sqldb-rbac           ║ manage SQL database        ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Security Auditor ║ Security Reader              ║ Subscription         ║ Read-only across all       ║
║                  ║ Reader                       ║ Subscription         ║ resources & security policy║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Network Engineer ║ Network Contributor          ║ rg-rbac-network      ║ Manage VNets, NSGs,        ║
║                  ║                              ║                      ║ subnets only               ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Read-Only User   ║ Reader                       ║ rg-rbac-dev          ║ View dev resources only;   ║
║                  ║                              ║                      ║ zero write permissions     ║
╠══════════════════╬══════════════════════════════╬══════════════════════╬════════════════════════════╣
║ Key Vault Admin  ║ Key Vault Administrator      ║ kv-rbac-lab          ║ Manage secrets, keys,      ║
║                  ║                              ║                      ║ and certificates           ║
╚══════════════════╩══════════════════════════════╩══════════════════════╩════════════════════════════╝
```


**Legend**

| Role | Meaning |
|---|---|
| **Owner** | Full control including role assignment |
| **Contributor** | Create / update / delete resources; cannot assign roles |
| **Reader** | Read-only; cannot modify anything |
| **Data-plane roles** | Apply to data operations (blobs, SQL rows, KV secrets); independent of ARM |

---

## 4. Role Scope Diagram

Roles cascade **downward** through the hierarchy. A role assigned at Subscription scope
is automatically inherited by every Resource Group and resource beneath it.

```text
Subscription  (Owner → Lab Admin)
│
├─ [inherited by all RGs] ◄── Security Reader  (Security Auditor)
│                          ◄── Reader           (Security Auditor)
│
├── rg-rbac-admin
│       └── kv-rbac-lab ◄──────────────── Key Vault Administrator  (KV Admin)
│
├── rg-rbac-dev ◄────────────────────────── Contributor  (Developer)
│       │                                   Reader       (Read-Only User)
│       └── [inherited] App Service · App Insights · App Service Plan
│
├── rg-rbac-network ◄─────────────────────── Network Contributor  (Network Engineer)
│       │                                    Reader                (Developer)
│       └── [inherited] VNet · snet-app · snet-data · NSG
│
└── rg-rbac-data
├── st-rbac-data ◄──────────────── Storage Blob Data Contributor  (Data Engineer)
└── sqldb-rbac   ◄──────────────── SQL DB Contributor             (Data Engineer)
```

```text
Scope Inheritance Direction
─────────────────────────────
Subscription
│  ← roles flow DOWN
▼
Resource Group
│
▼
Resource  ←── data-plane roles assigned HERE
(do NOT inherit from ARM control-plane assignments)
```


---

## 5. Control Plane Flow

Every Azure API call travels through this authorization pipeline before an operation
is allowed or denied.

```text
User / Service Principal / Managed Identity
│
│  (1) Authenticate
▼
┌────────────────────────┐
│   Azure AD / Entra ID  │  Issues bearer token containing:
│                        │  • User Object ID
│                        │  • Group memberships
└───────────┬────────────┘
│  (2) Bearer Token attached to request
▼
┌────────────────────────────────────────────────┐
│           Azure Resource Manager (ARM)          │
│                                                │
│  (3) Authorization evaluation:                 │
│      a) Resolve all role assignments           │
│         (direct + inherited from parent scope) │
│      b) Compute effective permissions          │
│         (union of grants minus deny assignments│
│      c) Evaluate Azure Policy conditions       │
│         (if applicable)                        │
└───────────────────┬────────────────────────────┘
│
┌───────────┴───────────┐
│                       │
[PERMIT]               [DENY – HTTP 403]
│                       │
▼                       ▼
┌───────────────┐       ┌───────────────────┐
│   Resource    │       │  Error returned   │
│   Operation   │       │  to caller        │
│   Executed    │       └───────────────────┘
└───────┬───────┘
│  (4) Activity Log entry written
▼
┌───────────────────────────┐
│  Log Analytics Workspace  │
│  +  st-rbac-audit         │
└───────────────────────────┘
```


### Key Authorization Concepts

| Concept | Description |
|---|---|
| **Additive permissions** | RBAC roles combine; granting role A and role B gives the union of both |
| **Deny assignments** | Explicit deny overrides ALL role grants — takes precedence unconditionally |
| **Effective permissions** | (All direct grants ∪ all inherited grants) − deny assignments |
| **ARM vs. Data plane** | ARM governs resource management; data-plane uses separate role assignments |

---

## 6. Resource Relationship Map
```text
╔══════════════════════════════════════════════════════════════════╗
║  rg-rbac-network                                                ║
║                                                                 ║
║  Network Engineer ──► [VNet: vnet-rbac-lab]                    ║
║                           ├── snet-app  (10.0.1.0/24)          ║
║  Developer (Reader) ──►   └── snet-data (10.0.2.0/24)          ║
║                       [NSG: nsg-rbac-lab] → snet-app           ║
╚═══════════════════════════╤══════════════════════════════════════╝
│ subnet delegation / VNet integration
╔═══════════════════════════▼══════════════════════════════════════╗
║  rg-rbac-dev                                                    ║
║                                                                 ║
║  Developer ──────────► [App Service Plan]                       ║
║  Read-Only (Reader) ►      └──► [App Service: app-rbac-dev]    ║
║                                        │ telemetry              ║
║                         [App Insights] ◄┘                       ║
╚═══════════════════════════╤══════════════════════════════════════╝
│ app reads data from
╔═══════════════════════════▼══════════════════════════════════════╗
║  rg-rbac-data                                                   ║
║                                                                 ║
║  Data Engineer ──────► [SQL Server: sql-rbac-lab]              ║
║                             └──► [SQL DB: sqldb-rbac]          ║
║                         [Storage: st-rbac-data]                ║
║                             └── container: data-uploads        ║
╚═══════════════════════════╤══════════════════════════════════════╝
│ secrets + keys stored in
╔═══════════════════════════▼══════════════════════════════════════╗
║  rg-rbac-admin                                                  ║
║                                                                 ║
║  KV Admin ───────────► [Key Vault: kv-rbac-lab]                ║
║  Lab Admin ──────────►     ├── Secret: sql-connection-string    ║
║                            ├── Secret: storage-access-key      ║
║                            └── Certificate: app-tls-cert       ║
║                                                                 ║
║                        [Log Analytics WS] ◄── all diag logs    ║
║                        [Storage: st-rbac-audit] ◄── ARM logs   ║
╚══════════════════════════════════════════════════════════════════╝
```

Security Auditor reads across ALL resource groups
(Subscription-level Reader + Security Reader)


---

## 7. Terraform Module Structure

```text
terraform/
│
├── main.tf              # Root module — orchestrates all child modules
├── variables.tf         # Input variables (subscription_id, tenant_id, prefix…)
├── outputs.tf           # Exported values (resource IDs, role assignment IDs)
├── providers.tf         # azurerm + azuread provider blocks
├── terraform.tfvars     # Lab-specific values — NOT committed to source control
│
├── modules/
│   │
│   ├── resource-groups/     # All RGs with consistent tagging
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   ├── networking/          # VNet, subnets, NSG, NSG rules
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   ├── compute/             # App Service Plan + App Service
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   ├── data/                # SQL Server, SQL DB, Storage Account (data)
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   ├── security/            # Key Vault, Log Analytics, audit Storage Account
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   └── rbac/                # Azure AD users/groups + all role assignments
│       ├── main.tf
│       ├── variables.tf
│       └── role_assignments/
│           ├── lab_admin.tf
│           ├── developer.tf
│           ├── data_engineer.tf
│           ├── security_auditor.tf
│           ├── network_engineer.tf
│           ├── readonly_user.tf
│           └── kv_admin.tf
│
└── tests/
├── validate_rbac.sh          # CLI-based permission validation
└── expected_permissions.json # Canonical allow/deny truth table
```


### Module Dependency Graph
```text
providers.tf
│
├──► resource-groups ─────────────────────────────────┐
│          │                                          │
│          ├──► networking                            │
│          ├──► compute                               │
│          ├──► data                                  │
│          └──► security                              │
│                    │                                │
└───────────────────►└──► rbac ◄── (all scope IDs) ──┘
```


> **Note:** The `rbac` module must run **after** all infrastructure modules complete,
> because `azurerm_role_assignment` resources require the target scope IDs as inputs.

---

## 8. RBAC Assignment Flow

How Terraform provisions a role assignment end-to-end:
```text
┌────────────────────────────────────────────────────────────────────┐
│  Terraform Execution                                               │
│                                                                    │
│  Step 1 ── azuread_user / azuread_group created                   │
│                │                                                   │
│  Step 2 ── Infrastructure modules complete                         │
│            (RGs · VNet · SQL · Key Vault · Storage)               │
│                │                                                   │
│  Step 3 ── azurerm_role_assignment created                         │
│            ┌──────────────────────────────────────────┐           │
│            │  principal_id        = <object_id>       │           │
│            │  role_definition_name = "Contributor"    │           │
│            │  scope               = <resource_group_id>│          │
│            └──────────────────────────────────────────┘           │
│                │                                                   │
│  Step 4 ── ARM replicates assignment globally (~seconds to 2 min) │
│                │                                                   │
│  Step 5 ── validate_rbac.sh tests effective permissions           │
└────────────────────────────────────────────────────────────────────┘
```

```text
azurerm_role_assignment Resource Model
┌─────────────────────────────────────┐
│  name              GUID (auto)      │
│  scope             /subscriptions/…│
│  role_definition   built-in name   │
│    _name or _id    or custom GUID   │
│  principal_id      Object ID of    │
│                    user / group / SP│
└─────────────────────────────────────┘
```


---

## 9. Validation Paths

Each persona has a defined set of expected **ALLOW** and **DENY** operations
verified by the test script.
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Developer                                                          │
│                                                                              │
│  ✅ az webapp list --resource-group rg-rbac-dev                              │
│  ✅ az webapp restart --name app-rbac-dev --resource-group rg-rbac-dev       │
│  ✅ az network vnet list --resource-group rg-rbac-network   (Reader)         │
│  ❌ az network vnet create …            (no Network Contributor on dev RG)   │
│  ❌ az keyvault secret list --vault-name kv-rbac-lab                         │
│  ❌ az sql server list --resource-group rg-rbac-data                         │
└──────────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Data Engineer                                                      │
│                                                                              │
│  ✅ az storage blob upload … (container on st-rbac-data)                     │
│  ✅ az sql db show --name sqldb-rbac --server sql-rbac-lab                   │
│  ❌ az storage blob upload … (st-rbac-audit — different account)             │
│  ❌ az webapp restart …                                                      │
│  ❌ az role assignment create …                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Security Auditor                                                   │
│                                                                              │
│  ✅ az resource list --subscription <sub-id>        (Reader)                 │
│  ✅ az security assessment list                     (Security Reader)        │
│  ❌ az resource delete … (any resource)                                      │
│  ❌ az role assignment create …                                              │
│  ❌ az keyvault secret set …                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Network Engineer                                                   │
│                                                                              │
│  ✅ az network vnet subnet update …                                          │
│  ✅ az network nsg rule create …                                             │
│  ❌ az webapp list …                                                         │
│  ❌ az storage blob upload …                                                 │
│  ❌ az sql server create …                                                   │
└──────────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Key Vault Admin                                                    │
│                                                                              │
│  ✅ az keyvault secret set --vault-name kv-rbac-lab …                        │
│  ✅ az keyvault certificate list --vault-name kv-rbac-lab                    │
│  ❌ az keyvault delete …       (requires Owner/Contributor on RG)            │
│  ❌ az webapp list …                                                         │
│  ❌ az sql db show …                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  Persona: Read-Only User                                                     │
│                                                                              │
│  ✅ az webapp show --name app-rbac-dev --resource-group rg-rbac-dev          │
│  ✅ az resource list --resource-group rg-rbac-dev                            │
│  ❌ az webapp restart …                                                      │
│  ❌ az webapp config set …                                                   │
│  ❌ az resource delete …                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```


### Validation Script Logic
```text
validate_rbac.sh
│
├─ az login --service-principal   (per-persona credentials)
│
├─ Run ALLOW tests ── assert exit code == 0
│       └── FAIL ──► print ❌  missing or incorrect role assignment
│
├─ Run DENY tests ── assert exit code != 0  (HTTP 403 expected)
│       └── FAIL ──► print ⚠️   over-permissioned — least-privilege violation
│
└─ Summary report
├── Pass / Fail counts per persona
└── Exit 1 if any failure detected
```


---

## 10. Security Boundaries
```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOUNDARY 1 — Azure AD Authentication                                    │
│  Every identity must authenticate via Entra ID before any ARM call.     │
│  No anonymous access. MFA via Conditional Access (strongly recommended). │
└──────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOUNDARY 2 — ARM Authorization (RBAC)                                   │
│  Every ARM operation is evaluated against effective role assignments.    │
│  Principle of Least Privilege enforced per persona and per scope.        │
└──────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOUNDARY 3 — Data Plane Separation                                      │
│  ARM (control-plane) access ≠ data-plane access.                        │
│    • Storage Blob operations → Storage Blob Data Contributor required    │
│    • SQL queries             → SQL DB Contributor required               │
│    • Key Vault secret access → Key Vault data-plane role required        │
│  A Contributor on the RG does NOT automatically get data-plane access.  │
└──────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOUNDARY 4 — Network Segmentation                                       │
│    • snet-app  → App Service VNet integration only                       │
│    • snet-data → SQL Server private endpoint only                        │
│  NSG rules restrict lateral movement between subnets.                   │
│  Public internet access to SQL and Storage disabled by default.         │
└──────────────────────────────────────────────────────────────────────────┘
```
```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOUNDARY 5 — Audit & Observability                                      │
│  All ARM control-plane operations → Log Analytics + st-rbac-audit.      │
│  Diagnostic settings enabled on Key Vault, SQL Server, and Storage.     │
│  Security Auditor has read-only visibility across all boundaries.       │
│  Alerts can be configured in Log Analytics for privilege escalation.    │
└──────────────────────────────────────────────────────────────────────────┘
```


---

## 11. Quick Reference: Built-In Role IDs

Use these GUIDs with `role_definition_id` in Terraform for deterministic references.

| Role Name | Role Definition ID |
|---|---|
| Owner | `8e3af657-a8ff-443c-a75c-2fe8c4bcb635` |
| Contributor | `b24988ac-6180-42a0-ab88-20f7382dd24c` |
| Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
| Network Contributor | `4d97b98b-1d4f-4787-a291-c67834d212e7` |
| SQL DB Contributor | `9b7fa17d-e63e-47b0-bb0a-15c516ac86ec` |
| Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |
| Key Vault Administrator | `00482a5a-887f-4fb3-b363-3b7fe8e74483` |
| Security Reader | `39bc4728-0917-49c7-9d2c-d95423bc2eb4` |

---

*Azure RBAC Lab — ARCHITECTURE_DIAGRAM.md — Generated 2026-07-08*

Here's a summary of what's covered in each section:

| Section	| Contents| 
|---|---|
|Resource Hierarchy|	Full scope chain: Tenant → 2 Management Groups → Subscription → 4 Resource Groups → individual resources|
|Persona & Role Matrix|	7 personas × built-in roles with exact scope and access summary in a formatted table|
|Role Scope Diagram|	ASCII inheritance tree showing which roles cascade vs. which are data-plane scoped directly to a resource|
|Control Plane Flow|	Step-by-step ARM request lifecycle: Entra ID auth → ARM authz (grants + deny + policy) → permit/deny → audit log|
|Resource Relationship Map|	Visual 4-layer stack showing App Service → SQL/Storage → Key Vault cross-RG data flow with personas labeled|
|Terraform Module Structure|	Full directory tree + module dependency graph with rbac correctly sequenced last|
|RBAC Assignment Flow|	Terraform provisioning sequence with the azurerm_role_assignment resource model|
|Validation Paths|	Per-persona ✅ ALLOW / ❌ DENY Azure CLI test cases + validation script exit-code logic|
|Security Boundaries|	5 named boundaries: AuthN, ARM AuthZ, data-plane separation, network segmentation, audit|
|Quick Reference|	Built-in role GUIDs for role_definition_id Terraform references|

