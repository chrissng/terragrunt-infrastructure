include "root" {
  path = find_in_parent_folders()
}

include "migration_outputs" {
  path   = find_in_parent_folders(".tfmigrate.outputs.hcl")
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws//modules/zones?version=2.10.2"
}

prevent_destroy = true

inputs = {
  zones = {
    "terragrunt-infrastructure-demo.chrissng.net" = {
      comment       = "Demo hosted zone"
      force_destroy = false
    }
  }
}
