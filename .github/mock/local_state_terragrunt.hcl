remote_state {
  backend = "local"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = "dummy.tfstate"
  }
}

terraform {
  extra_arguments "common" {
    commands = get_terraform_commands_that_need_vars()

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars",
    ]
  }

  extra_arguments "init_args" {
    commands = [
      "init"
    ]
    arguments = [
      "-reconfigure"
    ]
  }
}
