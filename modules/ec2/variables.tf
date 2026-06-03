variable "public_subnet_id" {
    description = "ID cua Public Subnet (module vpc) de dat cho Bastion Host"
    type = string
}

variable "private_subnet_id" {
    description = "ID cua Private Subnet (module vpc) de dat cho EC2 noi bo"
    type = string
}

variable "public_sg_id" {
    description = "ID cua SecGroup (module security-group) cho Bastion Host"
    type = string
}

variable "private_sg_id" {
    description = "ID cua SecGroup (module security-group) cho Private EC2"
    type = string
}