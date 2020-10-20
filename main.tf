locals {
  tags = merge(
    var.tags
    )
}

resource "random_shuffle" "subnet_id" {
  input = var.subnet_ids
  result_count = 1
}

resource "aws_efs_file_system" "this" {
  tags = local.tags
}

resource "aws_security_group" "this" {
  name = format("k8s-%s-%s", var.project_name, aws_efs_file_system.this.id)
  description= format("EFS Persistent Volume for project %s", var.project_name)
  vpc_id = var.vpc_id

  ingress {
    description = "EFS from K8s cluster"
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_block ]
  }
}

resource "aws_efs_mount_target" "this" {
  file_system_id = aws_efs_file_system.this.id
  subnet_id = random_shuffle.subnet_id.result[0]

  security_groups = [ aws_security_group.this.id ]
}

data "template_file" "pv_manifest" {
  template = "${file("${path.module}/manifests/_pv_template.yaml")}"
  vars = {
    fs_id = aws_efs_file_system.this.id
    volume_name = var.volume_label
    volume_capacity = var.volume_capacity
    volume_access_mode = var.volume_access_mode
    volume_reclaim_policy = var.volume_reclaim_policy
    vpc_id = var.vpc_id
  }
}

resource "local_file" "pv_manifest_rendered" {
  content = data.template_file.pv_manifest.rendered
  filename = format("%s/%s-pv.yaml", var.output_path, var.volume_label)
  file_permission = "0600"
}

data "template_file" "pvc_manifest" {
  template = "${file("${path.module}/manifests/_pvc_template.yaml")}"
  vars = {
    pvc_name = var.volume_label
    volume_name = var.volume_label
    volume_access_mode = var.volume_access_mode
    volume_capacity = var.volume_capacity
  }
}

resource "local_file" "pvc_manifest_rendered" {
  content = data.template_file.pvc_manifest.rendered
  filename = format("%s/%s-pvc.yaml", var.output_path, var.volume_label)
  file_permission = "0600"
}
