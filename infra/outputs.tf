output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "browserless_ecs_vpc" {
  description = "ID of VPC created for ECS browserless cluster"
  value       = aws_vpc.vpc.id
}

output "alb_hostname" {
  value = aws_lb.main.dns_name
}
