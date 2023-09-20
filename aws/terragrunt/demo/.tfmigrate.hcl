tfmigrate {
  migration_dir              = "./tfmigrate"
  is_backend_terraform_cloud = false
  history {
    storage "s3" {
      bucket = "chrissng-terragrunt-infrastructure-demo-terraform"
      key    = "tfmigrate/demo/history.json"
      region = "ap-northeast-1"
    }
  }
}
