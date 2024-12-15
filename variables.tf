variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  default = "10.0.3.0/24"
}

variable "ami_id" {
  default = "ami-0c02fb55956c7d316" # Replace with your region's AMI
}

variable "instance_type" {
  default = "t2.micro"
}

