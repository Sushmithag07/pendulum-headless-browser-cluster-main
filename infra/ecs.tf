resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster-${terraform.workspace}"
}

resource "aws_ecs_task_definition" "main" {
  network_mode             = "awsvpc"
  family                   = "${var.app_name}-task-definition-${terraform.workspace}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "${var.app_name}-container-${terraform.workspace}"
    image     = "${var.container_image[terraform.workspace]}:latest"
    essential = true
    environment = [{
      "name" : var.container_environment
    }]
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
  }])
}

resource "aws_ecs_service" "ecs_service" {
  count                              = length(var.ecs_services["host_name"])
  name                               = "${var.app_name}-${var.ecs_services["service_name"][count.index]}-svc-${terraform.workspace}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = element(aws_alb_target_group.ecs_target_group.*.arn, count.index)
    container_name   = "${var.app_name}-container-${terraform.workspace}"
    container_port   = var.container_port
  }
  /* 
    Ignoring task_definition for every time a new version of task_definition is created
    Ignoring desired for autoscaling in place
  */
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
  depends_on = [aws_alb_target_group.main, aws_iam_policy.s3, aws_iam_role.ecs_task_role, aws_iam_role.ecs_task_execution_role, aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment]
}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = length(var.ecs_services["host_name"])
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${element(aws_ecs_service.ecs_service.*.name, count.index)}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  count              = length(var.ecs_services["host_name"])
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.ecs_target.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.ecs_target.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.ecs_target.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 80
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  count              = length(var.ecs_services["host_name"])
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.ecs_target.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.ecs_target.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.ecs_target.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}