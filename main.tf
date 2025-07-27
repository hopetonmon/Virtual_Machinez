#-------------PROVIDER CONFIGURATION---------------------
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

#----------------CLOUD CONFIGURATION--------------------------------
  cloud {
    organization = "Foundationmon"
    workspaces {
      name = "Virtual_Machinez"
    }
  }
}