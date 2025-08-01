#-------------PROVIDER CONFIGURATION---------------------
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

#----------------CLOUD CONFIGURATION--------------------------------
  cloud {
    organization = "Foundationmon"
    workspaces {
      name = "Virtual_Machinez"
    }
  }
}

#-----------------------VARIABLES-----------------------------
variable "HOPETONMON_COPY_ACCESS_KEY" {
    description = "HopetonMon Copy AWS Access Key"
    type        = string
    sensitive = true
}

variable "HOPETONMON_COPY_SECRET_KEY" {
    description = "HopetonMon Copy AWS Secret Key"
    type        = string
    sensitive = true
  
}

variable "AWS_REGION" {
    description = "AWS Region"
    type        = string
}

variable "AVAILABILITY_ZONE" {
    description = "Availability Zone (Distinct loaction in the Region)"
    type        = string
}

variable "AVAILABILITY_ZONE2" {
    description = "Availability Zone 2 (Distinct loaction in the Region)"
    type        = string
  
}


#------------------PROVIDER DEFINITION----------------------
provider "aws" {
    region     = var.AWS_REGION
    access_key = var.HOPETONMON_COPY_ACCESS_KEY
    secret_key = var.HOPETONMON_COPY_SECRET_KEY
  
}

#-------------------VPC---------------------
resource "aws_vpc" "vm_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true #Enables or disables DNS resolution within the VPC.
    enable_dns_hostnames = true # Enables or disables the assignment of public DNS hostnames to instances launched in the VPC.
    tags = {
        Name = "vm_vpc"
    }
}

#-------------------SUBNETS---------------------
resource "aws_subnet" "public_subnet1" {
    vpc_id            = aws_vpc.vm_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone =  var.AVAILABILITY_ZONE
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "public_subnet1"
    }
}

#-------------------INTERNET GATEWAY---------------------
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vm_vpc.id
    tags = {
        Name = "igw"
    }
}

#-------------------ROUTE TABLE---------------------
resource "aws_route_table" "igw_route_table" {
    vpc_id = aws_vpc.vm_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
  
}
    tags = {
        Name = "igw_route_table"
    }
}

#-------------------ROUTE TABLE ASSOCIATION---------------------
resource "aws_route_table_association" "public_subnet1_route_table_assoc" {
    subnet_id      = aws_subnet.public_subnet1.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.igw_route_table.id
}

#-------------------SECURITY GROUP---------------------
resource "aws_security_group" "sg" {
    vpc_id = aws_vpc.vm_vpc.id
    name   = "sg"
    description = "Allow HTTP and SSH traffic " #Should only allow SSH form know ip addresses.
  
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allow HTTP traffic from anywhere
    } 
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allow SSH traffic from any(where
    }
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allow HTTPS traffic from anywhere
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1" #Allow all outbound traffic with any protocol
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "web_sg"
    }
}

#-------------------LAUNCH TEMPLATE---------------------
# Launch template for your Linux VM
resource "aws_launch_template" "linux_vm" {
  name_prefix   = "linux-vm-"
  image_id      = "ami-0b59bfac6be064b78" # Amazon Linux 2 in us-east-1, update if needed
  instance_type = "t2.micro"

  key_name = "car_key"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg.id]
    subnet_id                   = aws_subnet.public_subnet1.id
  }

  # Optional: user data to install desktop environment & RDP server (P=2ez)
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install mate-desktop1.x -y
    sudo yum install xrdp -y
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    # Set password for ec2-user
    echo "ec2-user:2ez" | sudo chpasswd
    # Open firewall for RDP
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    sudo firewall-cmd --permanent --add-port=3389/tcp
    sudo firewall-cmd --reload
  EOF
}

#--------------------------OUTPUTS----------------
output "vm_instance_details" {
  description = "Details of the EC2 VM instance"
  value = {
    public_ip       = aws_instance.linux_vm.public_ip
    public_dns      = aws_instance.linux_vm.public_dns
    instance_id     = aws_instance.linux_vm.id
    availability_zone = aws_instance.linux_vm.availability_zone
  }
}