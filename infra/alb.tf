resource "aws_lb" "main" {
  name               = "${var.app_name}-alb-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "main" {
  name        = "${var.app_name}-tg-${terraform.workspace}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200,301,403"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
  depends_on = [
    aws_lb.main
  ]
}

resource "aws_alb_target_group" "ecs_target_group" {
  count       = length(var.ecs_services["host_name"])
  name        = "${var.app_name}-${var.ecs_services["service_name"][count.index]}-tg-${terraform.workspace}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path[terraform.workspace]
    unhealthy_threshold = "2"
    port                = 3000
  }
  depends_on = [
    aws_lb.main, aws_alb_listener.http
  ]
}
/*
resource "aws_alb_target_group" "ecs_discovery" {
  name        = "${var.app_name}-discovery-tg-${terraform.workspace}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
    port                = 3000
  }
  depends_on = [
    aws_lb.main
  ]
}
*/

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.id
  }
}

resource "aws_lb_listener_rule" "ecs_service" {
  count        = length(var.ecs_services["host_name"])
  listener_arn = aws_alb_listener.http.arn
  priority     = var.ecs_services_rule_priority[count.index]

  action {
    type             = "forward"
    target_group_arn = element(aws_alb_target_group.ecs_target_group.*.arn, count.index)
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  condition {
    host_header {
      values = ["${var.ecs_services["host_name"][count.index]}.com"]
    }
  }

}
/*
resource "aws_lb_listener_rule" "discovery_service" {
  listener_arn = aws_alb_listener.http.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_discovery.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
    host_header {
      values = ["discovery.com"]
    }
  }

}
*/
output "aws_alb_target_group_arn" {
  value = aws_alb_target_group.main.arn
}
