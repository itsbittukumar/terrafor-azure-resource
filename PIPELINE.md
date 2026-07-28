# Deploying via Pipeline (GitHub Actions)

This turns local `terraform apply` into: **PR → review plan → merge → auto-deploy.**

## Prerequisites (in addition to the local ones)

| # | What | Why |
|---|---|---|
| 1 | A GitHub repo with this project pushed to it | Pipeline runs from your repo |
| 2 | Azure Service Principal | Non-interactive identity for the pipeline to authenticate as |
| 3 | GitHub repo secrets configured | Keeps credentials out of code |
| 4 | The remote state backend already bootstrapped (`bootstrap-backend.sh`, Step 2 of local guide) | Pipeline needs somewhere to read/write state too |

## Step 1: Push this project to a GitHub repo

```bash
cd terraform-defender-lab
git init
git add .
git commit -m "Initial modular Terraform setup for defender lab"
git branch -M main
git remote add origin https://github.com/<your-org>/<your-repo>.git
git push -u origin main
```

`.gitignore` already excludes `terraform.tfvars`, `.terraform/`, and `*.tfstate` — confirm
nothing sensitive got committed:
```bash
git log --stat
```

## Step 2: Create the Service Principal (once, locally)

```bash
az ad sp create-for-rbac \
  --name "sp-terraform-defender-lab" \
  --role="Contributor" \
  --scopes="/subscriptions/16fb91c7-f0fe-4be3-8e79-09cb933f7355" \
  --sdk-auth
```
Copy the 4 values from the JSON output: `clientId`, `clientSecret`, `tenantId`, `subscriptionId`.

## Step 3: Add GitHub Secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `clientId` from Step 2 |
| `AZURE_CLIENT_SECRET` | `clientSecret` from Step 2 |
| `AZURE_TENANT_ID` | `tenantId` from Step 2 |
| `AZURE_SUBSCRIPTION_ID` | `subscriptionId` from Step 2 |
| `TF_VAR_VM_SSH_PUBLIC_KEY` | your `~/.ssh/id_rsa.pub` contents |
| `TF_VAR_SQL_ADMIN_PASSWORD` | a strong password |
| `TF_BACKEND_STORAGE_ACCOUNT` | storage account name from `bootstrap-backend.sh` |

## Step 4: (Optional but recommended) Require manual approval before apply

Repo → **Settings → Environments → New environment → name it `production`** → enable
"Required reviewers" and add yourself/your team. The `apply` job in the workflow already
targets `environment: production`, so once this is set, every apply pauses for a human click
before it touches Azure — this is your safety gate replacing the manual "read the plan" step
you did locally.

## Step 5: How the pipeline behaves

The workflow file is at `.github/workflows/terraform.yml`. It has two jobs:

**On every Pull Request** touching `environments/lab/**` or `modules/**`:
- `terraform init`, `fmt -check`, `validate`, `plan`
- Posts the full plan output as a comment on the PR — so a reviewer sees exactly what will
  change before approving

**On every push/merge to `main`:**
- `terraform apply -auto-approve` — runs the change automatically (pauses for manual approval
  first if you set up Step 4)

## Step 6: Your day-to-day workflow becomes

1. Create a branch: `git checkout -b delete-function-app`
2. Edit `environments/lab/terraform.tfvars` (e.g., remove a resource entry)
3. Commit and push: `git commit -am "remove function app" && git push`
4. Open a PR — the bot comments the plan automatically
5. Review the plan comment — confirm the destroy count matches your intent
6. Merge — the apply job runs automatically (or waits for your approval click)
7. Check Actions tab for the run result

This is the same map-based create/delete pattern as before — the only difference is the
plan/apply steps now run in GitHub's infrastructure instead of your terminal, with a built-in
review checkpoint via the PR comment.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Error: building AzureRM Client: obtain subscription() from Azure CLI` | The pipeline uses the Service Principal via `ARM_*` env vars, not `az login` — confirm all 4 `AZURE_*` secrets are set correctly |
| Backend init fails with "storage account not found" | Confirm `TF_BACKEND_STORAGE_ACCOUNT` secret matches exactly what `bootstrap-backend.sh` printed |
| Plan comment doesn't appear on PR | Check the Actions tab for the `plan` job logs — usually a permissions issue; ensure repo Settings → Actions → Workflow permissions is set to "Read and write" |
| Apply job runs without asking approval | You skipped Step 4 — set up the `production` environment with required reviewers |
