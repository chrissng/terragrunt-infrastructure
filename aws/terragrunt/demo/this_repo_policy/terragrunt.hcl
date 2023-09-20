include "root" {
  path = find_in_parent_folders()
}

include "migration_outputs" {
  path   = find_in_parent_folders(".tfmigrate.outputs.hcl")
  expose = true
}

terraform {
  source = ".//."
}

prevent_destroy = true

inputs = {}
