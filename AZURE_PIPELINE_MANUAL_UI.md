# Azure Pipelines — Manual UI Setup (Classic Editor, No YAML)

This builds the same Plan → Approve → Apply flow entirely by clicking through the Azure DevOps
UI. Two pieces: a **Build pipeline** (runs Plan) and a **Release pipeline** (runs Apply, with
an approval gate).

---

## Prerequisite: everything from "Phase 1" and "Phase 2" of the previous guide still applies

You still need, before starting below:
- Code pushed to Azure Repos (or GitHub)
- The state backend bootstrapped (`bootstrap-backend.sh`)
- A Service Connection created (Project Settings → Service connections → New → Azure Resource
  Manager → Service principal (automatic) → name it `sc-terraform-defender-lab`)

If you haven't done those, do them first — the rest of this guide assumes they exist.

---

## Part A: Build Pipeline (Terraform Plan) — Classic Editor

### A.1 Start pipeline creation

1. **Pipelines** → **Pipelines** → **New pipeline**
2. Choose your source: **Azure Repos Git** (select your repo)
3. On the "Configure your pipeline" screen, scroll to the **bottom** and click
   **Use the classic editor** (this is the link that skips YAML entirely)
4. Select your repository and branch (`main`) → **Continue**
5. On the template screen, choose **Empty job** (top of the list, under "Start with an Empty pipeline")

### A.2 Set the agent pool

1. Click on **Agent job 1** (the default stage created)
2. Under **Agent pool**, select **Azure Pipelines**
3. Under **Agent specification**, choose **ubuntu-latest**

### A.3 Add Task 1 — Install Terraform

1. Click the **+** next to Agent job 1 to add a task
2. Search for **"Command line"** → **Add**
3. Click the newly added task, configure:
   - **Display name**: `Install Terraform`
   - **Script**:
     ```bash
     curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
     unzip -o terraform.zip
     sudo mv terraform /usr/local/bin/
     terraform -version
     ```

### A.4 Add Task 2 — Terraform Init

1. Click **+** again → search **"Azure CLI"** → **Add**
2. Configure:
   - **Display name**: `Terraform Init`
   - **Azure Resource Manager connection**: select `sc-terraform-defender-lab`
   - **Script Type**: `Bash`
   - **Script Location**: `Inline script`
   - **Inline Script**:
     ```bash
     cd environments/lab
     export ARM_SUBSCRIPTION_ID=$(AZURE_SUBSCRIPTION_ID)
     terraform init -backend-config="storage_account_name=$(TF_BACKEND_STORAGE_ACCOUNT)"
     ```
   - Scroll down to **Advanced** → check ✅ **Access service principal details in script** (this
     is the UI equivalent of `addSpnToEnvironment: true` — it exposes `$servicePrincipalId`,
     `$servicePrincipalKey`, `$tenantId` as env vars, but simplest is to still rely on the CLI
     login context which this task provides automatically)

### A.5 Add Task 3 — Terraform Validate

1. Click **+** → **Azure CLI** → **Add**
2. Configure:
   - **Display name**: `Terraform Validate`
   - **Azure Resource Manager connection**: `sc-terraform-defender-lab`
   - **Script Type**: `Bash`, **Script Location**: `Inline script`
   - **Inline Script**:
     ```bash
     cd environments/lab
     terraform fmt -check -recursive
     terraform validate
     ```

### A.6 Add Task 4 — Terraform Plan

1. Click **+** → **Azure CLI** → **Add**
2. Configure:
   - **Display name**: `Terraform Plan`
   - **Azure Resource Manager connection**: `sc-terraform-defender-lab`
   - **Script Type**: `Bash`, **Script Location**: `Inline script`
   - **Inline Script**:
     ```bash
     cd environments/lab
     export TF_VAR_subscription_id=$(AZURE_SUBSCRIPTION_ID)
     export TF_VAR_key_vault_tenant_id=$(AZURE_TENANT_ID)
     export TF_VAR_vm_admin_ssh_public_key="$(TF_VAR_VM_SSH_PUBLIC_KEY)"
     export TF_VAR_sql_admin_password="$(TF_VAR_SQL_ADMIN_PASSWORD)"
     terraform plan -out=tfplan
     terraform show -no-color tfplan > plan.txt
     cat plan.txt
     ```

### A.7 Add Task 5 — Publish the plan as a build artifact

This is what lets the Release pipeline pick up the exact reviewed plan later.

1. Click **+** → search **"Publish Build Artifacts"** → **Add**
2. Configure:
   - **Display name**: `Publish Terraform Plan`
   - **Path to publish**: `environments/lab`
   - **Artifact name**: `terraform-output`
   - **Artifact publish location**: `Azure Pipelines`

### A.8 Link the Variable Group

1. Click the **Variables** tab (top of the pipeline editor, next to Tasks)
2. Click **Variable groups** → **Link variable group**
3. Select `terraform-defender-lab-secrets` (create it first in Pipelines → Library if you
   haven't — same 5 variables as the YAML guide: `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`,
   `TF_BACKEND_STORAGE_ACCOUNT`, `TF_VAR_VM_SSH_PUBLIC_KEY` 🔒, `TF_VAR_SQL_ADMIN_PASSWORD` 🔒)
4. **Link**

### A.9 Set the trigger

1. Click the **Triggers** tab
2. Under **Continuous integration**, check ✅ **Enable continuous integration**
3. Branch filter: **Include** → `main`
4. (Optional) Click **Pull request validation** tab → ✅ **Enable pull request validation** →
   Branch filter **Include** → `main` — this makes Plan run automatically on every PR too

### A.10 Save

1. Click **Save** (top right) → **Save**
2. Name the pipeline: `terraform-defender-lab-plan`

Your Build pipeline (Plan) is done. It will now run on every push to `main` and every PR
targeting `main`.

---

## Part B: Release Pipeline (Terraform Apply) — with approval gate

### B.1 Create the release pipeline

1. **Pipelines** → **Releases** → **New pipeline**
2. On the template screen, click **Empty job** (top right, or "Start with an Empty job")
3. It creates **Stage 1** — rename it: click the stage name → type `Production` → click outside
   to save

### B.2 Add the build artifact

1. On the **Pipeline** tab (left side), click **Add an artifact**
2. **Source type**: `Build`
3. **Project**: your project
4. **Source (build pipeline)**: `terraform-defender-lab-plan` (the one from Part A)
5. **Default version**: `Latest`
6. **Source alias**: leave default
7. **Add**

### B.3 Enable the approval gate

1. On the artifact box, click the **lightning bolt icon** (Continuous deployment trigger) →
   toggle it **Enabled** → this makes a new release start automatically whenever the Build
   pipeline succeeds
2. Click on the **Production** stage box → click the **person icon** (Pre-deployment
   conditions) on the left edge of the stage
3. Under **Pre-deployment approvals**, toggle **Enabled**
4. **Approvers**: add yourself (or your team)
5. **Save**

This is your approval gate — every release will pause here until someone approves.

### B.4 Add tasks to the Production stage

1. Click **Tasks** (top tab) → select the **Production** stage from the dropdown
2. Click **Agent job** → set **Agent pool**: `Azure Pipelines`, **Agent Specification**:
   `ubuntu-latest`

**Task 1 — Install Terraform:**
1. Click **+** → **Command line** → **Add**
2. Configure:
   - **Display name**: `Install Terraform`
   - **Script**:
     ```bash
     curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
     unzip -o terraform.zip
     sudo mv terraform /usr/local/bin/
     ```

**Task 2 — Terraform Init:**
1. Click **+** → **Azure CLI** → **Add**
2. Configure:
   - **Display name**: `Terraform Init`
   - **Azure Resource Manager connection**: `sc-terraform-defender-lab`
   - **Script Type**: `Bash`, **Script Location**: `Inline script`
   - **Inline Script**:
     ```bash
     cd "$(System.DefaultWorkingDirectory)/_terraform-defender-lab-plan/terraform-output"
     export ARM_SUBSCRIPTION_ID=$(AZURE_SUBSCRIPTION_ID)
     terraform init -backend-config="storage_account_name=$(TF_BACKEND_STORAGE_ACCOUNT)"
     ```
   > The path `_terraform-defender-lab-plan/terraform-output` is how the release pipeline
   > references the downloaded artifact — the folder name is `_<build-pipeline-name>` followed
   > by the artifact name you set in A.7. Check the exact path via the **View releases** →
   > open a run → **Artifacts downloaded** log line if it doesn't match.

**Task 3 — Terraform Apply:**
1. Click **+** → **Azure CLI** → **Add**
2. Configure:
   - **Display name**: `Terraform Apply`
   - **Azure Resource Manager connection**: `sc-terraform-defender-lab`
   - **Script Type**: `Bash`, **Script Location**: `Inline script`
   - **Inline Script**:
     ```bash
     cd "$(System.DefaultWorkingDirectory)/_terraform-defender-lab-plan/terraform-output"
     export ARM_SUBSCRIPTION_ID=$(AZURE_SUBSCRIPTION_ID)
     terraform apply -auto-approve tfplan
     ```

### B.5 Link the variable group here too

1. Click the **Variables** tab → **Variable groups** → **Link variable group**
2. Select `terraform-defender-lab-secrets` → **Link**

### B.6 Save

1. **Save** (top right) → name it `terraform-defender-lab-release` → **OK**

---

## Part C: Run it end to end

1. Make a change: edit `environments/lab/terraform.tfvars`, commit, push to `main`
2. The Build pipeline (`terraform-defender-lab-plan`) triggers automatically
3. Watch it run: **Pipelines** → **Pipelines** → click the running job → confirm the `Terraform
   Plan` task log shows the expected create/destroy count
4. Once the build succeeds, the Release pipeline auto-triggers (from B.3's lightning bolt)
5. Go to **Pipelines** → **Releases** → open the new release → it shows **Production** stage
   waiting → click **Approve**
6. It runs `Terraform Apply` using the exact plan file from the build

---

## Verify

```bash
az resource list --resource-group rg-defender-lab-2026 -o table
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Release can't find the artifact folder | Open the release run, expand **Download artifact - _terraform-defender-lab-plan** step, copy the exact printed path, use it in your Init/Apply scripts |
| `Terraform Apply` says "tfplan not found" | Confirm A.7's **Path to publish** was `environments/lab` (so `tfplan` sits directly inside the published `terraform-output` folder) |
| Release never appears after a build | Check B.3 step 1 — the lightning bolt (CD trigger) must be **Enabled**, not just artifact linked |
| Approval never shows up to approve | Check B.3 steps 3-5 were saved — reopen Pre-deployment conditions to confirm the approver is listed |
| "Classic editor" link missing on New Pipeline screen | It's at the very bottom of the "Where is your code" screen, below the source options — some orgs disable it via org policy (Organization Settings → Pipelines → Settings → "Disable creation of classic pipelines"); if disabled, ask an org admin to re-enable it, or fall back to the YAML method |

---

## UI method vs YAML method — when to use which

| | Classic UI (this guide) | YAML (`azure-pipelines.yml`) |
|---|---|---|
| Setup speed | Slower — lots of clicking | Faster once you know YAML |
| Versioned with code | No — pipeline definition lives only in Azure DevOps | Yes — lives in git, reviewable in PRs |
| Good for | Learning the pieces, one-off setups, teams uncomfortable with YAML | Ongoing, team-scale, auditable infra pipelines |
| Migrating later | You can switch to YAML anytime — the underlying tasks are the same | |

For a lab or first-time setup, the UI method is genuinely a fine way to see how the pieces fit
before committing to YAML. For anything long-lived at org scale, YAML is worth migrating to
once you're comfortable, since the pipeline definition itself then gets code review like
everything else.
