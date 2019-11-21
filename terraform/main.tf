#------------------------------------------------------------------------------
#  
# Terraform Configuration for 201 Automation Workshop  
# 
#------------------------------------------------------------------------------
#  TO BUILD:
#  Run 'terraform init' to download plugins
#  Run 'terraform plan' to see what will infra will be built
#  Run 'terraform apply' to create the inrfra and populate the Ansible inventory
#    ... then run the Ansible playbook ../ansible/main.yaml
#
# TO DESTROY:
#  Run 'terraform destroy' to remove configuration
#    ... then run the Ansible playbook ../ansible/destroy.yaml
#------------------------------------------------------------------------------

# DEFINE PROVIDER FOR AWS
provider "aws" {
  profile    = "default"
  region     = var.aws_region
}


# CREATE VPC IN AWS
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "dedicated"

  tags = {
    Name = "arch-autows201-tf"
    UKSE = var.uk_se_name
  }
}


# CREATE SUBNET FOR MGMT
resource "aws_subnet" "mgmt-a" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "mgmt-a"
    UKSE = var.uk_se_name
  }
}


# CREATE SUBNET FOR PUBLIC
resource "aws_subnet" "public-a" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "public-a"
    UKSE = var.uk_se_name
  }
}


# CREATE SECURITY GROUP FOR MGMT
resource "aws_security_group" "mgmt" {
  name        = "mgmt"
  description = "Allow TLS & SSH inbound traffic, and any outbound"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


# CREATE SECURITY GROUP FOR PUBLIC
resource "aws_security_group" "public" {
  name        = "public"
  description = "Allow HTTP & HTTPS inbound traffic, and any outbound"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


# CREATE INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "main"
    UK-SE = var.uk_se_name
  }
}


# CREATE DEFAULT ROUTE TABLE FOR VPC
resource "aws_route_table" "main-rt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "main"
    UK-SE = var.uk_se_name
  }
}


# ASSOCIATE ROUTE TABLE WITH MGMT SUBNET
resource "aws_route_table_association" "mgmt-a" {
  subnet_id      = "${aws_subnet.mgmt-a.id}"
  route_table_id = "${aws_route_table.main-rt.id}"
}


# ASSOCIATE ROUTE TABLE WITH PUBLIC SUBNET
resource "aws_route_table_association" "public-a" {
  subnet_id      = "${aws_subnet.public-a.id}"
  route_table_id = "${aws_route_table.main-rt.id}"
}


# CREATE BIGIP USING AMI
module bigip {
  source = "f5devcentral/bigip/aws"
  version = "0.1.2"

  prefix            = "bigip"
  f5_instance_count = 1
  ec2_key_name      = var.sshkey
  aws_secretmanager_secret_id = "my_bigip_password"
  mgmt_subnet_security_group_ids = [aws_security_group.mgmt.id]
  public_subnet_security_group_ids = [aws_security_group.public.id]
  vpc_mgmt_subnet_ids = [aws_subnet.mgmt-a.id]
  vpc_public_subnet_ids = [aws_subnet.public-a.id]
  # NEED TO ADD BELOW TO REPLACE DEFAULT IN MODULE
  f5_ami_search_name = "F5 Networks BIGIP-14.* PAYG - Best 25*"

}


# OUTOPUT MGMT PUBLIC IPS
output "mgmt_public_ips" {
  description = "List of BIG-IP public IP addresses for the management interfaces"
  value       = module.bigip.mgmt_public_ips
}


# OUTPUT MGMT DNS
output "mgmt_public_dns" {
  description = "List of BIG-IP public DNS records for the management interfaces"
  value       = module.bigip.mgmt_public_dns
}


# OUTPUT BIGIP MGMT PORT
output "mgmt_port" {
  description = "HTTPS Port used for the BIG-IP management interface"
  value       = module.bigip.mgmt_port
}


# OUTPUT BIGIP PUBLIC ENI ID
output "public_nic_ids" {
  description = "List of BIG-IP public network interface ids"
  value       = module.bigip.public_nic_ids
}


# OUTPUT BIGIP MGMT IP AND PUBLIC ENI ID TO ANSIBLE INVENTORY FILE
resource "local_file" "bigips_inventory" {
    content     = <<EOF
[bigips]
${module.bigip.mgmt_public_ips.0} aws_pub_eni_id=${module.bigip.public_nic_ids.0}
    EOF
    filename = "../ansible/inventory/bigips.ini"
}