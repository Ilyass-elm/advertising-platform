variable "region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"
}

variable "main_vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
    type = list(string)
    default = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidr" {
    type = list(string)
    default = [ "10.0.11.0/24", "10.0.12.0/24" ]
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "public_destination_cidr" {
  type = string
  default = "0.0.0.0/0"
}

variable "key" {
  type = string
  default = "app.zip"
  
}

variable "frontend_port" {
  type = number
  default = 5173
  
}

variable "backend_port" {
  type = number
  default = 4000
}