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
  type    = string
  default = "5Gi"
}

variable "volume_access_mode" {
  type    = string
  default = "ReadWriteMany"
}

variable "volume_reclaim_policy" {
  type    = string
  default = "Retain"
}

# Helm related variables
variable "generate_kustomize_files" {
  description = "Determines if the module will generate kustomization files. Otherwise, uses helm. Default: true"
  type    = bool
  default = true
}

variable "helm_repository" {
  description = "Where does the helm chart live? Default: https://derekbelrose.github.io/helm-charts"
  type = string
  default = "https://derekbelrose.github.io/helm-charts"
}

variable "helm_chart_version" {
  description = "The version of the helm chart to use to create this PV"
  type = string
  default = "0.2.0"
}

variable "pvc_helm_chart_version" {
  description = "The version of the helm chart to use to create this PV"
  type = string
  default = "0.1.0"
}

# Initial support for access points.  This version
# assumes one access point per namespace as a requirement
# that may be a bad assumption and may need refactoring.
# here is an example argument to the module:
#   access_points = {
#    "logging": {  # <-- by name space
#      uid : 1100
#      gid : 1100
#      c_uid : 1100
#      c_gid : 1100
#      c_permissions : 755
#      path : "/graylog"
#     }
#   }
variable "access_points" {
  type  = map
  validation {
    condition = (
      length(var.access_points) == 1
    )
    error_message = "The var.access_points should contain 1 entry, the permissions to map."
  }
  default = {}
}
