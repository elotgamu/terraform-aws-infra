terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws",
        version = "5.19.0"
    }
  }
}

provider "aws" {
  # configuration options
  region = "us-east-1"
  # remove this hardcode secrets
  access_key = ""
  secret_key = "" 
}

# resource "aws_instance" "ubuntu_server" {
#   ami = "ami-053b0d53c279acc90"
#   instance_type = "t2.micro"
#   tags = {
#     Name = "ubuntu"
#   }
# }


# resource "aws_vpc" "main_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = {
#     Name = "production"
#   }
# }

# resource "aws_subnet" "subnet-1" {
#   vpc_id = aws_vpc.main_vpc.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "prod-subnet"
#   }
# }

# 1) Create VPC
# 2) create Internet gateway (send traffic to)
# 3) Create Custom Route Table (optional but cool)
# 4) Create a subnet
# 5) associate subnet with routing table
# 6) Create security group to allow port 22, 80, 443
# 7) Create a network interface with an IP in the subnet from step 4
# 8) Assign an "elastic" (public) IP  to the network interface from  step 7
# 9) Create ubuntu server and install enable apache2

# 1) Create a VPC
resource "aws_vpc" "production_vpc" {
   cidr_block = "10.0.0.0/16"
   tags = {
     Name = "production"
   }
}

# 2) Create a Internet Gateway
resource "aws_internet_gateway" "default" {
  # bound the vpc production_vpc
  vpc_id = aws_vpc.production_vpc.id
}

# 3) Create a custom Route Table
resource "aws_route_table" "default" {
  vpc_id = aws_vpc.production_vpc.id

  # define ipv4 route
  route {
    # accept all incoming traffic
    cidr_block = "0.0.0.0/0"
    # connect to the gateway ID defined
    gateway_id = aws_internet_gateway.default.id
  }

  # define ipv6 traffic
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "production"
  }
}

# 4) Create subnet
resource "aws_subnet" "default-subnet" {
  vpc_id = aws_vpc.production_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# 5) Associate subnet (default-subnet) with routing table (default)
# we need the subnet Id and the route table Id
resource "aws_route_table_association" "default-routing-association" {
  subnet_id = aws_subnet.default-subnet.id
  route_table_id = aws_route_table.default.id
}

# 6) Security Group
# to allow incoming web request from the public (HTTPS and HTTP)
# and allow SSH traffic as well
resource "aws_security_group" "allow_public_traffic" {
  name = "allow_public_traffic"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.production_vpc.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
     cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_public_traffic"
  }
}

# 7) Create a network interface with
#    an IP that belongs to the subnet
#    from step 4
resource "aws_network_interface" "inet_default" {
  subnet_id = aws_subnet.default-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_public_traffic.id]
}

# 8) Public IP
resource "aws_eip" "public_ip" {
  domain = "vpc"
  #   instance = aws_instance.ubuntu_web_server.id
  network_interface = aws_network_interface.inet_default.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.default]
}

# 9) Create lamp server
resource "aws_instance" "ubuntu_web_server" {
  ami = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terraform-test-access_key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.inet_default.id
  }

  user_data = file("installApache.sh")

  tags = {
    Name = "web-server"
  }
}