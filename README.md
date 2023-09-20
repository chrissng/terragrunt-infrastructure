# Terragrunt Infrastructure

This repository contains the code and configuration for infrastructure managed with Terragrunt and automated using Github Actions.

Terraform is used for IaC, and [Terragrunt](https://github.com/gruntwork-io/terragrunt) manages the configuration in this directory. The [DRY](https://terragrunt.gruntwork.io/docs/features/keep-your-terraform-code-dry/) concept is adopted for code, remote state configuration, and CLI flags, as reflected in the directory structure of this repository.

Table of contents:

* [Infra stacks](#infra-stacks)
* [Operation](#operation)
* [Usage](#usage)
  * [Create new environment](#create-new-environment)
  * [Create new module](#create-new-module)
  * [Migrating or importing resources](#migrating-or-importing-resources)
  * [Migrating resources between modules](#migrating-resources-between-modules)
  * [Create or update Terragrunt module](#create-or-update-terragrunt-module)
  * [Destroy Terragrunt modules](#destroy-terragrunt-modules)
* [Optimizing Github Actions workflow](#optimizing-github-actions-workflow)

---

## Infra stacks

Currently, the following platforms and environments are managed:

### Demo environment

* Demo: `<repo_root>/aws/terragrunt/demo/`

## Operation

Operations are automated using Github Actions. As a matter of general knowledge, `run-all` commands are used to make changes to an environment.

```bash
# Study the changes proposed by Terraform
terragrunt run-all plan

# Confirm and apply the changes
terragrunt run-all apply
```

Depending on which directory these commands are executed, it is possible to operate on the **entire** stack (all platforms and environments) by running the command. However, it is recommended to apply changes to each environment one at a time.

### GitOps

When a PR is created, Github Action workflow will run on any changes to environments defined in `<repo_root>/aws/terragrunt`. Depending on the changes, the workflow will

* Migrate state, or
* Plan and apply changes, or
* Plan and destroy a Terragrunt module.

If a new environment is introduced, it is necessary to configure the Github Action workflow. For e.g. [Demo env](.github/workflows/terragrunt_operation_demo_env.yaml). Please follow the naming conventions.

## Usage

### Create new environment

If a new enviroment is created, make directories under `<repo_root>/aws/terragrunt/[PLATFORM_NAME/]ENV_NAME/MODULE_NAME`.

```text
infrastructure (repo root)
└── aws
    └── terragrunt
        ├── ..
        └── demo       # Environment
            ├── vpc    # Module for VPC configuration
            └── batch  # Module for AWS Batch jobs
```

For example, to create a new `demo` environment, we will start from `<repo_root>/aws/terragrunt/demo`. We refer to this as the environment root.

Under the environment root, the following config files are required as a minimum:

* `.tfmigrate.hcl` - Tfmigrate config file, [example](aws/terragrunt/demo/.tfmigrate.hcl)
* `.tfmigrate.outputs.hcl` - Outputs used by Terragrunt during migration when dependencies are used, [example](aws/terragrunt/demo/.tfmigrate.outputs.hcl)
* `terragrunt.hcl` - Root terragrunt config file, [example](aws/terragrunt/demo/terragrunt.hcl)

#### `terragrunt.hcl` for environment root

`terragrunt.hcl` for the environment root must include the following, which defines the remote state for all modules in the environment.

```hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "chrissng-terragrunt-infrastructure-demo-terraform"
    region         = "ap-northeast-1
    dynamodb_table = "chrissng-terragrunt-infrastructure-demo-terraform"
    encrypt        = true

    key = "${local.environment}/${path_relative_to_include()}"
  }
}

locals {
  environment = basename(get_parent_terragrunt_dir())
}
```

In the same example, we also created two modules vpc and batch. Follow the next section on how to create new modules.

### Create new module

Module dependencies are specified [explicitly](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#dependencies-between-modules). This eliminates cyclical dependencies as the code evolve over time due to changes to the infrastructure. Furthermore, output values from a module can be [passed](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#passing-outputs-between-modules) into other modules as inputs.

Each Terragrunt directory, should contain the following files:

* `terraform.tfvars` - Statically defined input values. This is optional if there are no values to be defined.
* `terragrunt.hcl` - [Terragrunt configuration](https://terragrunt.gruntwork.io/docs/getting-started/configuration/#terragrunt-configuration-file)

#### `terragrunt.hcl` per module

`terragrunt.hcl` in each Terragrunt module must include the following:

```hcl
include "root" {
  path = find_in_parent_folders()
}

prevent_destroy = true
```

If dependency is used:

```hcl
include "migration_outputs" {
  path   = find_in_parent_folders(".tfmigrate.outputs.hcl")
  expose = true
}

dependency "<module_a>" {
  config_path = "<relative_path_to_module_a>"

  skip_outputs = get_env("TG_SKIP_OUTPUTS", false)
  mock_outputs = include.migration_outputs.locals.<module_a>
}
```

### Migrating or importing resources

Each environment contains a `./tfmigrate` directory. Add the typical resources you want to move or import using the tfmigrate state operation:

```hcl
migration "state" "import_lb_acm" {
  dir     = "./lb" # this refers to the target module
  force   = true   # If the state in which the terraform plan difference after import is expected, set this to true.
  actions = [
    "import 'aws_acm_certificate.staging_acm' arn:aws:acm:ap-northeast-1:0123:certificate/abc123",
  ]
}
```

### Migrating resources between modules

Each environment contains a `./tfmigrate` directory. Use the tfmigrate multi_state operation:

```hcl
migration "multi_state" "move_entire_backend" {
  from_dir = "./base" # Module where the resource(s) current reside
  to_dir   = "./s3"   # Module where the resources(s) will be moved to
  force    = true     # If the state in which the terraform plan difference after import is expected, set this to true.
  actions = [
    "mv 'aws_s3_bucket.s3[\"bucket-a\"]' 'aws_s3_bucket.s3[\"bucket-a\"]'",
    "mv 'aws_s3_bucket.s3[\"bucket-b\"]' 'aws_s3_bucket.s3[\"bucket-b\"]'",
    "xmv module.iam_assumable_role_admin_bucket.* module.iam_assumable_role_admin_bucket.$${1}",
  ]
}
```

#### Limitations of tfmigrate multi_state

1. You can only move resource from one module to another at a time in a single PR, i.e. you cannot migrate `base` -> `new1` and `base` -> `new2` in a single PR.
1. As part of the migration if you have refactored the modules and referenced outputs of dependency modules, it is also necessary to set the values statically for the migration to succeed. For example in Demo Env, [`.tfmigrate.outputs.hcl`](./aws/terragrunt/demo/.tfmigrate.outputs.hcl) is used to defined all values used by all the terragrunt modules. These static values are only used in migration operation.
    * Static values cannot be secrets, so avoid passing secrets. If you require secrets managed in other modules, use a data source, or use tfmigrate state rm and import

### Create or update Terragrunt module

Just make the usual changes and create the PR. Workflow will plan and apply changes to the entire environment.

### Destroy Terragrunt modules

Two step process:

1. PR to mark Terragrunt modules to be destroyed by setting `prevent_destroy = false` in `terragrunt.hcl`.
    * Workflow will look out for this setting and destroy the module *when PR is merged and workflow run is approved.*
    * It is necessary to destroy one module at a time (one PR each) as the workflow is not smart enough to destroy in the right order. If you have multiple modules to destroy, you need to ensure you are destroying the child modules first.
1. Final PR to remove the Terragrunt module files completely
    * Workflow will run apply again on the whole project *when the PR is merged and workflow run is approved.*

## Optimizing Github Actions workflow

Terragrunt operations (plan and apply) are applied per environment. As the number of modules increases within each environment, the execution time also increases. This represents a trade-off between maintaining a very large module (i.e., a large state) and using many small modules. One optimization is to execute `run-all plan/apply` only on modules that have been modified.
