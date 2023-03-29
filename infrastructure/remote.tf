# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

## TODO: add note around using Terraform remote state
terraform {
  backend "remote" {
    organization = "YOUR_TERRAFORM_CLOUD_ORGANIZATION_NAME_HERE"

    workspaces {
      name = "consul-global-scale-benchmark-infrastructure"
    }
  }
}
