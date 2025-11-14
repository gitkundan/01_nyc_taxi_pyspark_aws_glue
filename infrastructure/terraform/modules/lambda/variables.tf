variable "name_prefix" { type = string }
variable "role_arn" { type = string }
variable "handler" { type = string }
variable "runtime" { type = string }
variable "package_path" { type = string }
variable "env" { type = map(string) }
variable "tags" { type = map(string) }
