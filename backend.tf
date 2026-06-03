terraform {
  backend "s3" {
    bucket       = "terraform-state-nhom9"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}