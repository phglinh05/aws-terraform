variable "aws_region" {
  description = "AWS Region de trien khai ha tang"
  type        = string
  default     = "us-east-1"
}

variable "ip" {
  description = "IP ca nhan truy cap SSH vao Public EC2 (dinh dang CIDR, vi du: 1.2.3.4/32)"
  type        = string
}

variable "key_name" {
  description = "Ten key pair de SSH vao EC2"
  type        = string
}