# AWS Default VPC Equivalent for us-west-2

locals {
  # Default VPC uses 10.0.0.0/16 CIDR
  vpc_cidr = "10.0.0.0/16"
}

# Data source for us-west-2 availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. VPC
# AWS default VPC: CIDR 10.0.0.0/16, enableDNSHostnames=true, enableDNSSupport=true
resource "aws_vpc" "default" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "default"
  }
}

# 2. Main Internet Gateway
# AWS default VPC includes one Internet Gateway
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "igw-${aws_vpc.default.id}"
  }
}

# 3. Main Route Table
# AWS default VPC includes one main route table with:
# - Local route (10.0.0.0/16 -> local)
# - Internet route (0.0.0.0/0 -> igw)
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  route {
    cidr_block = local.vpc_cidr
  }

  tags = {
    Name = "main"
  }
}

# Associate route table with VPC
resource "aws_main_route_table_association" "default" {
  vpc_id         = aws_vpc.default.id
  route_table_id = aws_route_table.main.id
}

# 4. Default Security Group
# AWS default VPC includes one security group with:
# - All inbound/outbound traffic allowed (default behavior)
resource "aws_security_group" "default" {
  name        = "default"
  vpc_id      = aws_vpc.default.id
  description = "Default security group for the default VPC"

  tags = {
    Name = "default"
  }
}

# Associate default SG with VPC
resource "aws_vpc_endpoint_security_group_association" "default" {
  vpc_endpoint_id            = aws_vpc.default.id
  security_group_id = aws_security_group.default.id
}

# 5. Public Subnets (one per available AZ in us-west-2 - AWS default behavior)
resource "aws_subnet" "public" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.default.id
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "default-subnet-${count.index}"
    Type = "public"
  }
}

# 6. Public Route Tables (one per subnet - AWS default behavior)
resource "aws_route_table" "public" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "default-public-${count.index}"
  }
}

# 7. Associate public route tables with public subnets
resource "aws_route_table_association" "public" {
  count = length(data.aws_availability_zones.available.names)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}
