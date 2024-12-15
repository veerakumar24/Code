# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Create a Public Subnet
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Create a Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  tags = {
    Name = "private-subnet"
  }
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create a NAT Gateway for Private Subnet
resource "aws_eip" "nat" {
  #vpc = true
  domain = "vpc"

}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "nat-gateway"
  }
}

# Create a Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate Route Table with Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Create Security Group for Public Instances
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# Create Security Group for Private Instance
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}

# Create IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Generate a new SSH Key Pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS Key Pair using the generated public key
resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key" # Replace with your desired key name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Launch Public Instance
resource "aws_instance" "public" {
  count                  = 1
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  key_name               = aws_key_pair.ec2_key.key_name # Assign the key pair to the instance
  vpc_security_group_ids = [aws_security_group.public.id]
 user_data = <<-EOT
  #!/bin/bash
  echo "Starting Jenkins installation..." >> /var/log/user_data.log
  sudo yum update -y >> /var/log/user_data.log 2>&1
  sudo yum install -y java-1.8.0-openjdk wget >> /var/log/user_data.log 2>&1
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo >> /var/log/user_data.log 2>&1
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key >> /var/log/user_data.log 2>&1
  sudo yum install -y jenkins >> /var/log/user_data.log 2>&1
  sudo systemctl start jenkins >> /var/log/user_data.log 2>&1
  sudo systemctl enable jenkins >> /var/log/user_data.log 2>&1
  echo "Jenkins installation completed." >> /var/log/user_data.log
EOT


  tags = {
    Name = "public-instance-${count.index}"
  }
}

# Launch Private Instance
resource "aws_instance" "private" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.ec2_key.key_name # Assign the key pair to the instance
  vpc_security_group_ids = [aws_security_group.private.id]

  tags = {
    Name = "private-instance"
  }
}

# Save the private key to a local file
resource "local_file" "ec2_key_pem" {
  filename = "${path.module}/ec2-key.pem"
  content  = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400" # Optional: Restrict permissions to the file
}

#Amplify
resource "aws_amplify_app" "my_amplify_app" {
  name          = "my-amplify-app"
  repository    = "https://github.com/veerakumar24/WeAlvin-Devlopment" 
  #branch        = "main" # Specify the branch to deploy
  oauth_token   = var.github_oauth_token # GitHub Personal Access Token as a variable

  build_spec = <<BUILD_SPEC
version: 1
frontend:
  phases:
    build:
      commands:
        - cd frontend
        - npm install
        - npm run build
  artifacts:
    baseDirectory: frontend/build
    files:
      - "**/*"
  cache:
    paths:
      - frontend/node_modules/**/*
BUILD_SPEC

  environment_variables = {
    NODE_ENV = "production"
  }
}

resource "aws_amplify_branch" "main" {
  app_id = aws_amplify_app.my_amplify_app.id
  branch_name = "main"
  enable_auto_build = true
}
