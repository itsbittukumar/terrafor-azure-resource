# Deploying this project — step by step

## Step 0: Install tools (skip if already installed)

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

terraform -version   # confirm it's installed
az version            # confirm it's installed
```

## Step 1: Log in to Azure

```bash
az login
az account set --subscription "16fb91c7-f0fe-4be3-8e79-09cb933f7355"
az account show --query tenantId -o tsv   # copy this — you'll need it for key_vault_tenant_id
```

## Step 2: Create the remote state backend (one time only)

```bash
chmod +x bootstrap-backend.sh
./bootstrap-backend.sh
```

This prints a `storage_account_name`. Copy it.

## Step 3: Plug the backend name into the code

Open `environments/lab/backend.tf` and replace:
```hcl
storage_account_name = "sttfstateorgXXXXX"
```
with the actual name printed in Step 2.

## Step 4: Fill in your real values

```bash
cd environments/lab
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in:
- `key_vault_tenant_id` — from Step 1's `az account show` output
- `vm_admin_ssh_public_key` — run `cat ~/.ssh/id_rsa.pub` (generate one with `ssh-keygen` if you don't have one) and paste the output
- `sql_admin_password` — pick a strong password, OR skip putting it here and instead export it as an environment variable (safer, recommended):
```bash
export TF_VAR_sql_admin_password='YourStrongPassword123!'
```
If you use the environment variable, delete the `sql_admin_password` line from `terraform.tfvars`.

`terraform.tfvars` is already in `.gitignore` — it will never get committed to source control.

## Step 5: Initialize

The backend storage account name is deliberately NOT in `backend.tf` (so it never gets
committed to git and can be swapped between local/pipeline use). Pass it at init time:

```bash
terraform init -backend-config="storage_account_name=<name from Step 2>"
```

This downloads the `azurerm` provider and connects to your remote backend. You should see
`Terraform has been successfully initialized!` at the end.

## Step 6: Format and validate (catches typos before you waste a plan cycle)

```bash
terraform fmt -recursive
terraform validate
```

## Step 7: Plan

```bash
terraform plan -out=tfplan
```

Read the output carefully. At the bottom you should see something like:
```
Plan: 14 to add, 0 to change, 0 to destroy.
```

Check that number roughly matches what you expect (10 visible resources + a few companion
resources like Service Plans and the Function App's storage account = ~13-15).

## Step 8: Apply

```bash
terraform apply tfplan
```

Type nothing extra — because you already have a saved plan file (`tfplan`), it applies exactly
what you reviewed, with no surprise re-prompt.

This will take several minutes (VM + SQL Server are the slowest). When done, Terraform prints
outputs and returns you to the prompt.

## Step 9: Verify

```bash
az resource list --resource-group rg-defender-lab-2026 -o table
```

Compare this list against your original 10 resources in the Azure portal.

## Step 10 (later): Create or delete a resource

**Create:** add a new entry to the relevant map in `terraform.tfvars`, then repeat Steps 7-8.

**Delete:** remove the entry from the relevant map in `terraform.tfvars`, then repeat Steps 7-8.
Always check the `Plan:` summary line before typing yes — it should say destroy count = exactly
what you meant to remove, nothing more.

```bash
terraform plan -out=tfplan   # confirm the destroy count
terraform apply tfplan
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `Error: A resource with the ID ... already exists` | The resource already exists in Azure (e.g., created manually via portal) but isn't in Terraform state. Use `terraform import` to bring it under management, or delete it manually and let Terraform recreate it. |
| `Error: building account: unable to configure ResourceManagerAccount` | Run `az login` again — your session token expired. |
| Storage account name errors on Function App module | Storage account names must be globally unique, lowercase, no hyphens, 3-24 chars. The module auto-strips hyphens from your key, but if it still collides, add a random suffix. |
| Backend storage account name already exists | Re-run `bootstrap-backend.sh` — it appends a random number, so a re-run will pick a new name. |
