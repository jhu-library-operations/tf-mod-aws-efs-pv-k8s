locals {
  tags = merge(
    var.tags
    )

  product = setproduct(aws_efs_file_system.this.*.id, var.subnet_ids)
}

resource "aws_efs_file_system" "this" {
  count = length(var.namespaces)
  tags = merge(local.tags,
    { 
      Namespace = element(var.namespaces, count.index) 
      Name      = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
    }
    )
}

resource "aws_security_group" "this" {
  name = format("%s-%s-efs_filesystem", var.project_name, var.volume_label)
  description= format("EFS Persistent Volume for project %s", var.project_name)
  vpc_id = var.vpc_id

  ingress {
    description = "EFS from K8s cluster"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

resource "aws_efs_mount_target" "this" {
  count = length(local.product)
  file_system_id = element(local.product, count.index)[0]
  subnet_id = element(local.product, count.index)[1]
  security_groups = [ aws_security_group.this.id ]
}

resource "aws_efs_access_point" "this" {
  count = length(var.namespaces)
  file_system_id = aws_efs_file_system.this[count.index].id
  posix_user {
    uid = var.access_points[keys(var.access_points)[0]].uid
    gid = var.access_points[keys(var.access_points)[0]].gid
    secondary_gids = try(var.access_points[keys(var.access_points)[0]].secondary_gids, [])
  } 
  root_directory {
    path = var.access_points[keys(var.access_points)[0]].path
    creation_info {
      owner_uid = var.access_points[keys(var.access_points)[0]].c_uid
      owner_gid = var.access_points[keys(var.access_points)[0]].c_gid
      permissions = var.access_points[keys(var.access_points)[0]].c_permissions
    }
  }
}

# XXX: Should we be generating kustomization manifests based off of access
# points if they are defined?  This code assumes only one per namespace
# That may be a bad assumption, but this will be fine if that assumption 
# holds.
data "template_file" "pv_manifest" {
  count = length(var.namespaces)
  template = file("${path.module}/manifests/_pv_template.yaml")
  vars = {
    fs_id = element(aws_efs_file_system.this.*.id, count.index)
    fs_mount = try(format(":%s", element(aws_efs_access_point.this.*.id, count.index)), "/")
    volume_name = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
    volume_capacity = var.volume_capacity
    volume_access_mode = var.volume_access_mode
    volume_reclaim_policy = var.volume_reclaim_policy
    vpc_id                = var.vpc_id
  }
}

resource "local_file" "pv_manifest_rendered" {
  count = length(var.namespaces)
  content = element(data.template_file.pv_manifest.*.rendered, count.index)
  filename = format("%s/%s/volumes/%s/pv.yaml", var.output_path, element(var.namespaces, count.index), var.volume_label)
  file_permission = "0600"
}

data "template_file" "pvc_manifest" {
  count = length(var.namespaces)
  template = file("${path.module}/manifests/_pvc_template.yaml")
  vars = {
    pvc_name = var.volume_label
    volume_name = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
    volume_access_mode = var.volume_access_mode
    volume_capacity    = var.volume_capacity
  }
}

resource "helm_release" "persistentvolume" {
  # Only run if var.generate_kustomize_files is set to false
  count = var.generate_kustomize_files ? 0 : length(var.namespaces)
  name = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
  repository = var.helm_repository
  chart = "aws-efs-pv"
  version = var.helm_chart_version

  set {
    name = "Namespace"
    value = element(var.namespaces, count.index)
  }

  set {
    name = "size"
    value = var.volume_capacity
  }

  set {
    name = "reclaimpolicy"
    value = var.volume_reclaim_policy
  }
  
  set {
    name = "handle"
    value = try(format("%s:%s", element(aws_efs_file_system.this.*.id, count.index),
      element(aws_efs_access_point.this.*.id, count.index)), format("%s", element(aws_efs_file_system.this.*.id, count.index)))
  }
}

resource "local_file" "pvc_manifest_rendered" {
  count = length(var.namespaces)
  content = element(data.template_file.pvc_manifest.*.rendered, count.index)
  filename = format("%s/%s/volumes/%s/pvc.yaml", var.output_path, element(var.namespaces, count.index), var.volume_label)
  file_permission = "0600"
}

data "template_file" "kustomize_volume" {
  template = file("${path.module}/manifests/_kustomization_volume.yaml")
}

resource "local_file" "kustomize_volume" {
  count = length(var.namespaces)
  content = data.template_file.kustomize_volume.rendered
  filename = format("%s/%s/volumes/%s/kustomization.yaml", var.output_path, element(var.namespaces, count.index), var.volume_label)

  file_permission = "0600"
}

resource "helm_release" "persistentvolumeclaim" {
  depends_on = [ helm_release.persistentvolume ]
  count = var.generate_kustomize_files ? 0 : length(var.namespaces)
  name = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
  namespace = element(var.namespaces, count.index)
  repository = var.helm_repository
  chart = "aws-efs-pvc"
  version = "0.1.0"

  set {
    name = "volumename"
    value = format("%s-%s", var.volume_label, element(var.namespaces, count.index))
  }

  set {
    name =  "size"
    value = var.volume_capacity
  }
}
