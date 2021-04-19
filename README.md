# Consul Global Scale Benchmark

The repository contains Terraform config and scripts required to run the [Consul Global Scale Benckmark](https://hashicorp.com/cgsb) for HashiCorp [Consul](https://consul.io) on [Amazon Web Services](https://https://aws.amazon.com/).

## Prerequisites

* HashiCorp [Terraform](https://terraform.io) v0.13.5

## Structure

There are two Terraform projects that help setup the experiment.

1. [infrastructure](./infrastructure) - This directory contains the Terraform configuration for setting up the infrastructure
for the experiment.

2. [services](./services) - This directory contains the Terraform configuration for the services that run on the Kubernetes and Nomad clusters.

## Provisioning Infrastructure

The benchmark uses Terraform to initialize infrastructure.

### Prerequisites

* [Terraform Cloud](https://www.terraform.io/cloud) account. Follow [this](https://learn.hashicorp.com/tutorials/terraform/cloud-sign-up?in=terraform/cloud-get-started) tutorial to sign up.

Edit `infrastructure/remote.tf` file and add Terraform Cloud organization name.

```hcl
terraform {
  backend "remote" {
    organization = "YOUR_TERRAFORM_CLOUD_ORGANIZATION_NAME_HERE"

    workspaces {
      name = "consul-scalability-challenge-infrastructure"
    }
  }
}
```

_Note: Any Terraform [remote backends](https://www.terraform.io/docs/language/settings/backends/remote.html) can be used for this project._

### Create Infrastructure via HashiCorp Terraform

```bash
cd infrastructure
```

Initialize Terraform

```bash
terraform init
```

Run Terraform apply

```bash
terraform apply -var="key_name=consul-global-scale-challenge" -var="datadog_api_key=${DATADOG_API_KEY}" -parallelism="100"
```

