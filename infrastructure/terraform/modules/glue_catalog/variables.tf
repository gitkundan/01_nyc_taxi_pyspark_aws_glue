variable "database_name" { type = string }
variable "bronze_location" { type = string }
variable "bronze_columns" { type = list(object({ name = string, type = string })) }
