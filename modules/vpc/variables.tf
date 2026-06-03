variable "vpc_cidr" {
  description = "Dai IP cho toan bo VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Dai IP cua Public Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Dai IP cua Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "vpc_name" {
  description = "Ten cua VPC"
  type        = string
  default     = "VPC"
}