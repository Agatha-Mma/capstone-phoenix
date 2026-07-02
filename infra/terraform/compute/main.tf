variable "subnet_ids" {}
variable "sg_id" {}
variable "key_name" {}
variable "instance_type" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name
  source_dest_check      = false
  tags = {
    Name = "k3s-control-plane"
    Role = "server"
  }
}

resource "aws_instance" "workers" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name
  source_dest_check      = false
  tags = {
    Name = "k3s-worker-${count.index}"
    Role = "agent"
  }
}

output "control_plane_public_ip" {
  value = aws_instance.control_plane.public_ip
}
output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}
output "worker_public_ips" {
  value = aws_instance.workers[*].public_ip
}
output "worker_private_ips" {
  value = aws_instance.workers[*].private_ip
}
