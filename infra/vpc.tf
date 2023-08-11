resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    "Name" = "${var.app_name}-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "${var.app_name}-${terraform.workspace}"
  }
}

resource "aws_subnet" "public" {
  cidr_block              = element(var.public_subnets, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.app_name}-${terraform.workspace}-pub0"
  }
}

resource "aws_subnet" "private" {
  cidr_block              = element(var.private_subnets, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.private_subnets)
  map_public_ip_on_launch = false
  tags = {
    "Name" = "${var.app_name}-${terraform.workspace}-priv0"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.app_name}-${terraform.workspace}"
  }
}

resource "aws_route" "default_public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

/*
resource "aws_ec2_transit_gateway_vpc_attachment" "internet_gateway_attachment" {
  vpc_id = aws_vpc.vpc.arn
}
*/
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = element(aws_subnet.public.*.id, count.index)
}

resource "aws_eip" "nat_gateway_attachment" {
  count = length(var.private_subnets)
  vpc   = true
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = length(var.private_subnets)
  allocation_id = element(aws_eip.nat_gateway_attachment.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  tags = {
    Name = "${var.app_name}-${terraform.workspace}-${count.index}"
  }
}

resource "aws_route_table" "private_route_table" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private_route" {
  count                  = length(compact(var.private_subnets))
  route_table_id         = element(aws_route_table.private_route_table.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat_gateway.*.id, count.index)
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(var.private_subnets)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
}

resource "aws_security_group" "alb" {
  name   = "${var.app_name}-sg-alb-${terraform.workspace}"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    self             = true
  }

  ingress {
    protocol         = "tcp"
    from_port        = 3000
    to_port          = 3000
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    self             = true
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    self             = true
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.app_name}-sg-task-${terraform.workspace}"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol         = "tcp"
    from_port        = var.container_port
    to_port          = var.container_port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 3000
    to_port          = 3000
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_groups  = [aws_security_group.alb.id]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

/*
resource "aws_service_discovery_private_dns_namespace" "service_discovery_namespace" {
  name = var.service_discovery_endpoint
  vpc  = aws_vpc.vpc.arn
}
*/