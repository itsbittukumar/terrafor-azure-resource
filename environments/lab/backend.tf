terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  # storage_account_name is intentionally omitted here so it can be supplied
  # at init time via -backend-config, both locally and in the pipeline —
  # this keeps the value out of source control.
  backend "azurerm" {
    resource_group_name = "rg-tfstate"
    container_name       = "tfstate"
    key                  = "defender-lab.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
