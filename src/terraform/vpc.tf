resource "aws_vpc" "main_vpc" {
  cidr_block = var.main_vpc_cidr
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.public_subnet_cidr
  map_public_ip_on_launch = true
}

resource "aws_subnet" "backend" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  vpc_id = aws_vpc.main_vpc.id
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet.id
}

resource "aws_route_table" "backend_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "rt_association" {
  subnet_id = aws_subnet.backend.id
  route_table_id = aws_route_table.backend_rt.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Endpoint for S3 Bucket so that backend can communicate with it
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_endpoint_type = "Gateway"
  vpc_id = aws_vpc.main_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.public_rt.id]
}