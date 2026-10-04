### S3 Bucket to store zip and config files
resource "aws_s3_bucket" "app_bucket" {
  bucket = "test-bucket-adpf-2026"
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "app_zip" {
  bucket = aws_s3_bucket.app_bucket.id
  key = var.key
  source = "${path.module}/scripts/${var.key}"
  etag = filemd5("${path.module}/scripts/${var.key}")
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

### iam role to grant the ec2 instance the download ###

resource "aws_iam_role" "ec2_role" {
  name = "ec2_download-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  }

  )
  
}
resource "aws_iam_role_policy" "ec2_download_policy" {
  name = "download-zip-files"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.app_bucket.arn}/${var.key}"
    }]
  })
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
  
}
### Frontend instance: data source, ec2, and security groups ###

# Data source for the latest Amazon Linux 2 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "frontend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.frontend_sg.id ]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    s3_bucket = aws_s3_bucket.app_bucket.id
    s3_key = var.key
    aws_region = var.region
    backend_ip_address = ""#output.backend_ip_address
    component = "frontend"
    deploy_dir = "/dev/app"
    zip_file = "app.zip"
    image_name = "frontend-img"
    container_name = "frontend-dev"
    host_port = var.frontend_port
    container_port = var.frontend_port
  })
}

resource "aws_security_group" "frontend_sg" {
  name = "frontend-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description = "Application access"
    from_port = var.frontend_port
    to_port = var.frontend_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "frontend-sg"
  }
  
}

### Backend instance ### 

resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.backend.id
  vpc_security_group_ids = [ aws_security_group.backend_sg.id ]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    s3_bucket = aws_s3_bucket.app_bucket.id
    s3_key = var.key
    aws_region = var.region
    component = "backend"
    deploy_dir = "/dev/app"
    zip_file = "app.zip"
    image_name = "backend-img:latest"
    container_name = "backend-dev"
    host_port = 4000
    container_port = 4000
  })
}

resource "aws_security_group" "backend_sg" {
  name = "backend-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description = "Application access"
    from_port = var.backend_port
    to_port = var.backend_port
    protocol = "tcp"
    security_groups = [ aws_security_group.frontend_sg.id ]

  }
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "backend-sg"
  }
}
