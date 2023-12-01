terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-north-1"
}

variable "availability_zone" {
  type        = string
  description = "Subnet AZ (must match prerequisites)"
  default     = "eu-north-1b"
}

resource "aws_vpc" "womm-vpc-01" {
  cidr_block            = "172.16.0.0/16"
#   enable_dns_hostnames  = true

  tags = {
    Name = "womm-vpc-01"
  }
}

resource "aws_subnet" "womm-subnet-01" {
  vpc_id                  = aws_vpc.womm-vpc-01.id
  cidr_block              = "172.16.50.0/24"
#   map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = {
    Name = "womm-subnet-01"
  }

  depends_on = [ aws_internet_gateway.gw ]
}

resource "aws_route53_zone" "dev" {
  name = "dev.example.com"

  vpc {
    vpc_id = aws_vpc.womm-vpc-01.id
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_route53_record" "dev-ns" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "TST01"
  type    = "A"
  ttl     = "30"
  records = ["172.16.50.50"]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.womm-vpc-01.id
}

resource "aws_route_table" "womm-route-01" {
  vpc_id = aws_vpc.womm-vpc-01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "womm-route-table-01"
  }
}

resource "aws_route_table_association" "womm-route-assoc-01" {
  subnet_id = aws_subnet.womm-subnet-01.id
  route_table_id = aws_route_table.womm-route-01.id
}

# resource "aws_vpc_dhcp_options" "dns_resolver" {
#   domain_name_servers = aws_route53_zone.dev.name_servers
# }

# resource "aws_vpc_dhcp_options_association" "dns_resolver" {
#   vpc_id          = aws_vpc.womm-vpc-01.id
#   dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
# }
