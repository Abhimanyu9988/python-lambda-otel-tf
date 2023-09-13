# AWS AZ
variable "aws_az" {
  type        = string
  description = "AWS AZ"
  default     = "us-west-2a"
}
# VPC Variables
variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.0.0.0/24"

}
# Subnet Variables
variable "public_subnet_cidr" {
  type        = string
  description = "CIDR for the public subnet"
  default     = "10.0.0.0/24"
}
