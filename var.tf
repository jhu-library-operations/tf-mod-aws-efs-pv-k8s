variable "project_name" {
  type = string
}

variable "namespaces" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "tags" {
  default = {}
}
variable "output_path" {}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_cidr_block" {
  type = string
}

variable "volume_label" {
  type = string
}

variable "volume_capacity" {
  type = string
  default = "5Gi"
}

variable "volume_access_mode" {
  type = string
  default = "ReadWriteMany"
}

variable "volume_reclaim_policy" {
  type = string
  default = "Retain"
}
