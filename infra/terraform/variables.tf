variable "aws_region" {
  default = "us-east-1"
}
variable "my_ip" {
  description = "Your home IP in CIDR form, e.g. 1.2.3.4/32"
}
variable "instance_type" {
  default = "t3.small"
}
variable "key_name" {
  default = "capstone-phoenix-key"
}
