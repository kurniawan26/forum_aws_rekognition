output "ec2_public_ip" {
  description = "IP publik EC2 (Elastic IP)"
  value       = aws_eip.app.public_ip
}

output "ec2_public_dns" {
  description = "DNS publik EC2"
  value       = aws_instance.app.public_dns
}

output "s3_bucket_name" {
  description = "Nama S3 bucket untuk uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "s3_bucket_arn" {
  description = "ARN S3 bucket"
  value       = aws_s3_bucket.uploads.arn
}

output "ssh_command" {
  description = "Command SSH ke EC2"
  value       = "ssh ubuntu@${aws_eip.app.public_ip}"
}

output "app_url" {
  description = "URL aplikasi"
  value       = "http://${aws_eip.app.public_ip}"
}

output "iam_role_arn" {
  description = "ARN IAM role EC2 (pakai Instance Profile, tidak perlu akses key manual)"
  value       = aws_iam_role.ec2.arn
}
