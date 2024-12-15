output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_instance_ids" {
  value = aws_instance.public[*].id
}

output "private_instance_id" {
  value = aws_instance.private.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

# Output the private key for local storage
output "ec2_private_key" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}
