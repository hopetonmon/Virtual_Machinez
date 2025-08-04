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
# Launch template for Ubuntu 22.04 with MATE + RDP
resource "aws_launch_template" "vm_launch_template" {
  name_prefix   = "vm-launch-template-"
  image_id      = data.aws_ami.ubuntu_22_04_x86.id # Ubuntu 22.04 LTS x86_64 in us-east-2
  instance_type = "t3.micro"              # Free-tier eligible and Nitro/UEFI supported
  key_name      = "car_key"

  vpc_security_group_ids = [aws_security_group.sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -eux

    # 1. Set RDP password for ec2-user (create if missing)
    id -u ec2-user || useradd -m ec2-user
    echo "ec2-user:YourStrongPassword123" | chpasswd

    # 2. Update packages and install MATE Desktop + xrdp
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-mate-desktop xrdp

    # 3. Enable and start xrdp
    systemctl enable xrdp
    systemctl restart xrdp

    # 4. Configure .xsession for MATE
    echo "mate-session" > /home/ec2-user/.xsession
    chown ec2-user:ec2-user /home/ec2-user/.xsession
    chmod +x /home/ec2-user/.xsession

    # 5. Optional: open RDP port if ufw enabled
    if systemctl is-active --quiet ufw; then
      ufw allow 3389/tcp
      ufw reload
    fi
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ubuntu-mate-rdp"
  }
}

#------------AWS INSTANCE----------------------
resource "aws_instance" "linux_vm" {
  depends_on = [aws_launch_template.vm_launch_template, aws_subnet.public_subnet1]
  
  # Add the subnet_id argument here
  subnet_id = aws_subnet.public_subnet1.id

  launch_template {
    id      = aws_launch_template.vm_launch_template.id
    version = "$Latest"
  }
}

#---------------------DATA---------------------

# Get the latest Ubuntu 22.04 LTS x86_64 AMI in us-east-2
data "aws_ami" "ubuntu_22_04_x86" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu images)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
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