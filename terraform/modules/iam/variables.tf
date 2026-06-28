variable "dev_user_name" {
  type = string
}

variable "assets_bucket_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
