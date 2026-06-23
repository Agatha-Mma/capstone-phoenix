module "network" {
  source = "./network"
}

module "security" {
  source = "./security"
  vpc_id = module.network.vpc_id
  my_ip  = var.my_ip
}

module "compute" {
  source        = "./compute"
  subnet_ids    = module.network.subnet_ids
  sg_id         = module.security.sg_id
  key_name      = var.key_name
  instance_type = var.instance_type
}
