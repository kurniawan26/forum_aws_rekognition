variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "app_name" {
  description = "Nama aplikasi, dipakai sebagai prefix resource"
  type        = string
  default     = "forum-aws-rekognition"
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "demo", "prod"], var.environment)
    error_message = "Environment harus salah satu dari: dev, staging, demo, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key" {
  description = "Public key SSH untuk akses EC2 (isi dengan isi ~/.ssh/id_ed25519.pub)"
  type        = string
  sensitive   = true
}

variable "ssh_allowed_cidr" {
  description = "CIDR yang boleh SSH ke EC2, gunakan IP publik kamu/0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"
}

variable "secret_key_base" {
  description = "Phoenix SECRET_KEY_BASE (generate: mix phx.gen.secret)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password PostgreSQL"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain atau IP publik EC2 (untuk CORS S3 & config Phoenix)"
  type        = string
  default     = ""
}

variable "docker_image" {
  description = "Docker image dari Docker Hub, contoh: username/forum-aws-rekognition:latest"
  type        = string
}
