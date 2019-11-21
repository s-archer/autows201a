#------------------------------------------------------------------------------
# Variables used by Terraform Config. 
#------------------------------------------------------------------------------
#
# *** Important - Do not put credentials in this file. ***  
#
#------------------------------------------------------------------------------

# DEFINE UK SE NAME FOR USE IN TAGS
variable "uk_se_name" {
  type    = string
  default = "arch"
}


# DEFINE AWS REGION
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}


# DEFINE SSH KEY (AS NAMED IN AWS) FOR AWS AMI BUILD
variable "sshkey" {
  type    = string
  default = "arch_id_rsa"
}


# DEFINE SSH KEY (LOCAL PATH) FOR AWS AMI BUILD
variable "ssh_key_file_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}
#------------------------------------------------------------------------------