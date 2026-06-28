variable "bucket_name" {
  type = string
}

variable "lambda_arn" {
  type = string
}

variable "lambda_permission_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
