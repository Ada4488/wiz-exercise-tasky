variable "region" { type = string }
variable "name_prefix" { type = string } # e.g. "wiz"
variable "backup_bucket" { type = string }
variable "ec2_ssh_public_key" { type = string } # from repo secret