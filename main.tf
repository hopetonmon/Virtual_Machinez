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
    ingress {
    description      = "RDP"
    from_port        = 3389
    to_port          = 3389
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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
# Launch template for Linux AMI with desktop environment and RDP setup
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-launch-template-"
  image_id      = "ami-0b59bfac6be064b78"  # Replace with a suitable Linux AMI ID in us-east-2
  instance_type = "t2.micro"
  key_name      = "car_key"

  vpc_security_group_ids = [aws_security_group.sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update packages
    sudo yum update -y

    # Install desktop environment and xrdp
    sudo yum groupinstall "Server with GUI" -y
    sudo yum install xrdp -y

    # Enable and start xrdp
    sudo systemctl enable xrdp
    sudo systemctl start xrdp

    # Allow RDP through firewall
    sudo firewall-cmd --permanent --add-port=3389/tcp
    sudo firewall-cmd --reload

    # Create a new user (optional)
    sudo useradd -m -s /bin/bash ubuntu
    echo "ubuntu:your_password" | sudo chpasswd

    # Adjust SELinux if necessary
    sudo setsebool -P httpd_can_network_connect 1
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "linux-desktop-rdp"
  }
}
#------------AWS INSTANCE----------------------
resource "aws_instance" "linux_vm" {
  depends_on = [aws_launch_template.web_launch_template, aws_subnet.public_subnet1]
  
  # Add the subnet_id argument here
  subnet_id = aws_subnet.public_subnet1.id

  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }
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