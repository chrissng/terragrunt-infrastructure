remote_state {
  backend = "s3"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "chrissng-terragrunt-infrastructure-demo-terraform"
    region         = local.terraform_aws_region
    dynamodb_table = "chrissng-terragrunt-infrastructure-demo-terraform"
    encrypt        = true

    key = local.key

    s3_bucket_tags = {
      DoNotDelete = "true"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.terraform_aws_region}"
  default_tags {
    tags = {
      Source                  = "chrissng/terragrunt-infrastructure"
      Terragrunt_execute_path = "aws/terragrunt/demo"
      Managed_By              = "terraform"
    }
  }
}
EOF
}

terraform {
  extra_arguments "common" {
    commands = get_terraform_commands_that_need_vars()

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars",
    ]
  }

  before_hook "create_plugin_cache_dir" {
    commands = [
      "init",
      "apply",
      "plan"
    ]
    execute = ["mkdir", "-p", local.plugin_cache_dir]
  }

  extra_arguments "plugin_cache_dir" {
    commands = [
      "init",
      "apply",
      "plan"
    ]
    env_vars = {
      TF_PLUGIN_CACHE_DIR = local.plugin_cache_dir
    }
  }
}

locals {
  terraform_aws_region = "ap-northeast-1"
  environment          = basename(get_parent_terragrunt_dir())
  key                  = "${local.environment}/${path_relative_to_include()}"
  plugin_cache_dir     = "${get_env("TF_PLUGIN_CACHE_DIR", "/tmp/.terraform.d/plugin-cache")}/${local.key}"
}
