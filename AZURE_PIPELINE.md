# Deploying via Azure Pipelines — Complete Setup Guide

This walks through everything from zero: creating the Azure DevOps org, connecting to Azure,
storing secrets, and getting the pipeline to run end-to-end.

---

## Part 1: Azure DevOps setup

### 1.1 Create an Azure DevOps organization (skip if you already have one)

1. Go to https://dev.azure.com
2. Sign in with the same Microsoft/Azure AD account you use for the Azure subscription
3. Click **New organization**, follow the prompts (pick a region close to you)

### 1.2 Create a project

1. Inside your organization, click **New project**
2. Name it e.g. `defender-lab-infra`
3. Visibility: **Private**
4. Click **Create**

### 1.3 Push this code into Azure Repos

Option A — use Azure Repos as the source (simplest for a first setup):
```bash
cd terraform-defender-lab
git init
git add .
git commit -m "Initial modular Terraform setup"

# Get the clone URL from Project > Repos > Clone
git remote add origin https://dev.azure.com/<your-org>/defender-lab-infra/_git/defender-lab-infra
git push -u origin main
```

Option B — keep the code in GitHub and just point the Azure Pipeline at it (also fully
supported — Azure Pipelines can trigger off a GitHub repo). If you go this route, skip 1.3 and
during pipeline creation (Part 4) choose **GitHub** as the source instead of Azure Repos.

---

## Part 2: Connect Azure DevOps to your Azure subscription

This is the Azure DevOps equivalent of the Service Principal you'd create for GitHub Actions —
except Azure DevOps can create it for you automatically.

1. In your Azure DevOps project, go to **Project Settings** (bottom left) → **Service connections**
2. Click **New service connection**
3. Choose **Azure Resource Manager** → **Next**
4. Authentication method: **Service principal (automatic)** → **Next**
5. Scope level: **Subscription**
6. Subscription: select `Azure subscription 1` (`16fb91c7-f0fe-4be3-8e79-09cb933f7355`)
7. Resource Group: leave blank (scopes to whole subscription) — or pick `rg-defender-lab-2026`
   if you want to scope it tighter (more secure, but backend storage account is in a different
   RG, `rg-tfstate`, so subscription-level scope is simpler for this setup)
8. Service connection name: **`sc-terraform-defender-lab`** (must match exactly — this is the
   name referenced in `azure-pipelines.yml`)
9. Check **Grant access permission to all pipelines**
10. Click **Save**

Azure DevOps has now silently created a Service Principal in your Azure AD and granted it
Contributor access — no manual `az ad sp create-for-rbac` needed.

---

## Part 3: Store secrets in a Variable Group

1. In your project, go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name it exactly: **`terraform-defender-lab-secrets`** (must match the `group:` name in
   `azure-pipelines.yml`)
4. Add these variables:

| Name | Value | Mark as secret? |
|---|---|---|
| `AZURE_SUBSCRIPTION_ID` | `16fb91c7-f0fe-4be3-8e79-09cb933f7355` | No |
| `AZURE_TENANT_ID` | run `az account show --query tenantId -o tsv` to get it | No |
| `TF_BACKEND_STORAGE_ACCOUNT` | the name printed by `bootstrap-backend.sh` | No |
| `TF_VAR_VM_SSH_PUBLIC_KEY` | contents of `~/.ssh/id_rsa.pub` | Yes (click the lock icon) |
| `TF_VAR_SQL_ADMIN_PASSWORD` | a strong password | Yes (click the lock icon) |

5. Click **Save**

---

## Part 4: Bootstrap the remote state backend (if not already done)

Same as the local setup — run this once from your machine or Azure Cloud Shell:
```bash
az login
az account set --subscription "16fb91c7-f0fe-4be3-8e79-09cb933f7355"
chmod +x bootstrap-backend.sh
./bootstrap-backend.sh
```
Copy the printed storage account name into the Variable Group (`TF_BACKEND_STORAGE_ACCOUNT`)
from Part 3 if you haven't already.

---

## Part 5: Create an Environment with an approval gate

This is what makes `apply` pause for a human before touching Azure.

1. Go to **Pipelines** → **Environments**
2. Click **New environment**
3. Name it exactly: **`production`** (must match `environment: 'production'` in the YAML)
4. Resource: **None** → **Create**
5. Once created, click the **⋮** menu (top right) → **Approvals and checks**
6. Click **+** → **Approvals**
7. Add yourself (or your team) as an approver → **Create**

Now every run that reaches the `Apply` stage will pause and notify the approver, who must
click **Approve** before anything gets applied.

---

## Part 6: Create the pipeline

1. Go to **Pipelines** → **Pipelines** → **Create Pipeline**
2. Choose where your code lives: **Azure Repos Git** (or **GitHub**, if you went with Option B)
3. Select the repository
4. Choose **Existing Azure Pipelines YAML file**
5. Branch: `main`, Path: `/azure-pipelines.yml`
6. Click **Continue**
7. Review the YAML shown, click **Run** (this will actually kick off a run — that's fine, the
   first run will hit the Plan stage)

If the pipeline asks for permission to use the service connection or variable group the first
time, click **Permit**.

---

## Part 7: What happens now

**On this first run (from `main`):**
- `Plan` stage runs: installs Terraform, `init`, `fmt -check`, `validate`, `plan`
- Since it's on `main`, the `Apply` stage triggers next — but **pauses** waiting for your
  approval (Part 5)
- Go to the running pipeline, click **Review** → **Approve** to let it proceed
- `Apply` stage downloads the exact plan file from the `Plan` stage and applies it

**On future changes**, the normal flow is PR-based:
1. Create a branch: `git checkout -b delete-function-app`
2. Edit `environments/lab/terraform.tfvars`
3. Push, open a Pull Request against `main`
4. The PR triggers the `Plan` stage automatically — check the pipeline run linked to the PR,
   open the `plan.txt` artifact or the job logs to see exactly what will change
5. Merge the PR
6. The merge triggers a new run on `main` — `Plan` then `Apply` (pending your approval)

---

## Part 8: Verify a run worked

```bash
az resource list --resource-group rg-defender-lab-2026 -o table
```

Or check **Pipelines** → your pipeline → the completed run → both stages should show green.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `##[error]The pipeline is not valid. Job Apply: Environment production could not be found` | You skipped Part 5, or the environment name doesn't exactly match `production` |
| `##[error]No service connection found with name sc-terraform-defender-lab` | Name mismatch — check Project Settings > Service connections, or edit the `azureSubscription:` value in the YAML to match your actual connection name |
| Variable group values show blank in logs | Expected for secrets (masked) — check they're populated in Pipelines > Library, not that the pipeline is broken |
| `Error: building AzureRM Client: obtain subscription()...` | `addSpnToEnvironment: true` might be missing from a task, or `ARM_SUBSCRIPTION_ID` isn't being exported — check that step's inline script |
| Apply stage runs without ever pausing for approval | The Environment's approval check (Part 5, step 5-7) wasn't saved — revisit it |
| `terraform init` backend error: "Error: Error building ARM Config: obtain subscription() from Azure CLI" during init | The `AzureCLI@2` task needs `addSpnToEnvironment: true` set (already in the YAML) — if you customize the file, don't drop this |
| First pipeline run fails asking to authorize resources | Click **View** on the failed run, then **Permit** on the resource access prompts (variable group / service connection) — Azure DevOps requires explicit first-use authorization |

---

## Quick reference: what's what

| Azure DevOps concept | Purpose | Equivalent in GitHub Actions |
|---|---|---|
| Service Connection | Identity the pipeline authenticates as | Service Principal + repo secrets |
| Variable Group (Library) | Shared secrets/values across pipelines | Repo/Org secrets |
| Environment + Approval | Manual gate before a stage runs | Environment protection rules |
| `azure-pipelines.yml` | Pipeline definition | `.github/workflows/*.yml` |
| Stage / Job / Step | Pipeline structure | Job / Step |
