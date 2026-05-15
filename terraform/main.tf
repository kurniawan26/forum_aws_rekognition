terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state di S3 — WAJIB untuk production agar state tidak hilang.
  # Langkah setup:
  #   1. Buat bucket S3 manual: aws s3 mb s3://nama-bucket-tfstate --region ap-southeast-1
  #   2. Aktifkan versioning: aws s3api put-bucket-versioning --bucket nama-bucket-tfstate --versioning-configuration Status=Enabled
  #   3. Ganti "nama-bucket-tfstate-anda" di bawah lalu uncomment
  #   4. Jalankan: terraform init -migrate-state
  # backend "s3" {
  #   bucket = "nama-bucket-tfstate-anda"
  #   key    = "forum/terraform.tfstate"
  #   region = "ap-southeast-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ─── DATA ────────────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ─── VPC & NETWORK ───────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.app_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.app_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.app_name}-subnet-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.app_name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─── SECURITY GROUPS ─────────────────────────────────────────────────────────

resource "aws_security_group" "ec2" {
  name        = "${var.app_name}-ec2-sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-ec2-sg" }
}

# ─── IAM ROLE & INSTANCE PROFILE ─────────────────────────────────────────────

resource "aws_iam_role" "ec2" {
  name = "${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_rekognition" {
  name = "${var.app_name}-s3-rekognition-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectModerationLabels",
          "rekognition:DetectFaces",
          "rekognition:CompareFaces",
          "rekognition:DetectLabels"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.app_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.app_name}-instance-profile"
  role = aws_iam_role.ec2.name
}

# ─── S3 BUCKET ───────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.app_name}-uploads-${var.environment}"
  force_destroy = var.environment != "prod"

  tags = { Name = "${var.app_name}-uploads" }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["https://${var.domain_name}", "http://${aws_instance.app.public_ip}"]
    max_age_seconds = 3600
  }
}

# ─── SSM PARAMETER STORE (secrets) ───────────────────────────────────────────

resource "aws_ssm_parameter" "secret_key_base" {
  name  = "/${var.app_name}/SECRET_KEY_BASE"
  type  = "SecureString"
  value = var.secret_key_base

  tags = { App = var.app_name }
}

resource "aws_ssm_parameter" "database_url" {
  name  = "/${var.app_name}/DATABASE_URL"
  type  = "SecureString"
  value = "ecto://postgres:${var.db_password}@localhost/forum_aws_rekognition_prod"

  tags = { App = var.app_name }
}

# ─── EC2 INSTANCE ────────────────────────────────────────────────────────────

resource "aws_key_pair" "deployer" {
  key_name   = "${var.app_name}-deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_name     = var.app_name
    aws_region   = var.aws_region
    s3_bucket    = aws_s3_bucket.uploads.bucket
    db_password  = var.db_password
    domain_name  = var.domain_name
    docker_image = var.docker_image
  })

  tags = {
    Name        = "${var.app_name}-app"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "${var.app_name}-eip" }
}
