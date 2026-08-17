terraform {
  backend "s3" {
    bucket = "terraform-aws-platform-tfstate-051305442317"
    key    = "environments/dev/terraform.tfstate"
    region = "ap-southeast-1"

    use_lockfile = true
  }
}