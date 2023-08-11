data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "availability_zones" "available" {
  state = "available"
}

locals {
  CreateALB = !var.alb_workloads == ""
  CreateInternalALB = !var.internal_alb_workloads == ""
  DelegateDNS = !var.app_dns_name == ""
  ExportHTTPSListener = alltrue([
  local.CreateALB,
  var.create_https_listener == True
])
  ExportInternalHTTPSListener = alltrue([
  local.CreateInternalALB,
  var.create_internal_https_listener == True
])
  CreateEFS = !var.efs_workloads == ""
  CreateNATGateways = !var.nat_workloads == ""
  HasAliases = !var.aliases == ""
  stack_name = "headless-browser"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = True
  enable_dns_support = True
  instance_tenancy = "default"
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}"
    }
  ]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}"
    }
  ]
}

resource "aws_route" "default_public_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_internet_gateway" "internet_gateway" {
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}"
    }
  ]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "internet_gateway_attachment" {
  vpc_id = aws_vpc.vpc.arn
}

resource "aws_subnet" "public_subnet1" {
  cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.vpc.arn
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = True
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-pub0"
    }
  ]
}

resource "aws_subnet" "public_subnet2" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.arn
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = True
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-pub1"
    }
  ]
}

resource "aws_subnet" "private_subnet1" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.arn
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = False
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-priv0"
    }
  ]
}

resource "aws_subnet" "private_subnet2" {
  cidr_block = "10.0.3.0/24"
  vpc_id = aws_vpc.vpc.arn
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = False
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-priv1"
    }
  ]
}

resource "aws_route_table_association" "public_subnet1_route_table_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public_subnet1.id
}

resource "aws_route_table_association" "public_subnet2_route_table_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id = aws_subnet.public_subnet2.id
}

resource "aws_eip" "nat_gateway1_attachment" {
  count = locals.CreateNATGateways ? 1 : 0
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "nat_gateway1" {
  count = locals.CreateNATGateways ? 1 : 0
  allocation_id = aws_eip.nat_gateway1_attachment.allocation_id
  subnet_id = aws_subnet.public_subnet1.id
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-0"
    }
  ]
}

resource "aws_route_table" "private_route_table1" {
  count = locals.CreateNATGateways ? 1 : 0
  vpc_id = aws_vpc.vpc.arn
}

resource "aws_route" "private_route1" {
  count = locals.CreateNATGateways ? 1 : 0
  route_table_id = aws_route_table.private_route_table1[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway1[0].association_id
}

resource "aws_route_table_association" "private_route_table1_association" {
  count = locals.CreateNATGateways ? 1 : 0
  route_table_id = aws_route_table.private_route_table1[0].id
  subnet_id = aws_subnet.private_subnet1.id
}

resource "aws_eip" "nat_gateway2_attachment" {
  count = locals.CreateNATGateways ? 1 : 0
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "nat_gateway2" {
  count = locals.CreateNATGateways ? 1 : 0
  allocation_id = aws_eip.nat_gateway2_attachment.allocation_id
  subnet_id = aws_subnet.public_subnet2.id
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-1"
    }
  ]
}

resource "aws_route_table" "private_route_table2" {
  count = locals.CreateNATGateways ? 1 : 0
  vpc_id = aws_vpc.vpc.arn
}

resource "aws_route" "private_route2" {
  count = locals.CreateNATGateways ? 1 : 0
  route_table_id = aws_route_table.private_route_table2[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway2[0].association_id
}

resource "aws_route_table_association" "private_route_table2_association" {
  count = locals.CreateNATGateways ? 1 : 0
  route_table_id = aws_route_table.private_route_table2[0].id
  subnet_id = aws_subnet.private_subnet2.id
}

resource "aws_service_discovery_private_dns_namespace" "service_discovery_namespace" {
  name = var.service_discovery_endpoint
  vpc = aws_vpc.vpc.arn
}

resource "aws_ecs_cluster" "cluster" {
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]
  configuration {
    execute_command_configuration = {
      Logging = "DEFAULT"
    }
  }
  setting = [
    {
      name = "containerInsights"
      value = "disabled"
    }
  ]
}

resource "aws_security_group" "public_load_balancer_security_group" {
  count = locals.CreateALB ? 1 : 0
  description = "Access to the public facing load balancer"
  ingress = [
    {
      cidr_blocks = "0.0.0.0/0"
      description = "Allow from anyone on port 80"
      from_port = 80
      protocol = "tcp"
      to_port = 80
    },
    {
      cidr_blocks = "0.0.0.0/0"
      description = "Allow from anyone on port 443"
      from_port = 443
      protocol = "tcp"
      to_port = 443
    }
  ]
  vpc_id = aws_vpc.vpc.arn
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-lb"
    }
  ]
}

resource "aws_security_group" "internal_load_balancer_security_group" {
  count = locals.CreateInternalALB ? 1 : 0
  description = "Access to the internal load balancer"
  vpc_id = aws_vpc.vpc.arn
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-internal-lb"
    }
  ]
}

resource "aws_security_group" "environment_security_group" {
  description = join("", [var.app_name, "-", var.environment_name, "EnvironmentSecurityGroup"])
  vpc_id = aws_vpc.vpc.arn
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-env"
    }
  ]
}

resource "aws_security_group" "environment_security_group_ingress_from_public_alb" {
  count = locals.CreateALB ? 1 : 0
  description = "Ingress from the public ALB"
  // CF Property(GroupId) = aws_security_group.environment_security_group.arn
  // CF Property(IpProtocol) = -1
  vpc_id = aws_security_group.public_load_balancer_security_group[0].arn
}

resource "aws_security_group" "environment_security_group_ingress_from_internal_alb" {
  count = locals.CreateInternalALB ? 1 : 0
  description = "Ingress from the internal ALB"
  // CF Property(GroupId) = aws_security_group.environment_security_group.arn
  // CF Property(IpProtocol) = -1
  vpc_id = aws_security_group.internal_load_balancer_security_group[0].arn
}

resource "aws_security_group" "environment_security_group_ingress_from_self" {
  description = "Ingress from other containers in the same security group"
  // CF Property(GroupId) = aws_security_group.environment_security_group.arn
  // CF Property(IpProtocol) = -1
  vpc_id = aws_security_group.environment_security_group.arn
}

resource "aws_security_group" "internal_alb_ingress_from_environment_security_group" {
  count = locals.CreateInternalALB ? 1 : 0
  description = "Ingress from the env security group"
  // CF Property(GroupId) = aws_security_group.internal_load_balancer_security_group[0].arn
  // CF Property(IpProtocol) = -1
  vpc_id = aws_security_group.environment_security_group.arn
}

resource "aws_wafv2_regex_pattern_set" "public_load_balancer" {
  count = locals.CreateALB ? 1 : 0
  // CF Property(Scheme) = "internet-facing"
  // CF Property(SecurityGroups) = [
  //   aws_security_group.public_load_balancer_security_group.id
  // ]
  // CF Property(Subnets) = [
  //   aws_subnet.public_subnet1.id,
  //   aws_subnet.public_subnet2.id
  // ]
  // CF Property(Type) = "application"
}

resource "aws_inspector_resource_group" "default_http_target_group" {
  count = locals.CreateALB ? 1 : 0
  // CF Property(HealthCheckIntervalSeconds) = 10
  // CF Property(HealthyThresholdCount) = 2
  // CF Property(HealthCheckTimeoutSeconds) = 5
  // CF Property(Port) = 80
  // CF Property(Protocol) = "HTTP"
  // CF Property(TargetGroupAttributes) = [
  //   {
  //     Key = "deregistration_delay.timeout_seconds"
  //     Value = 60
  //   }
  // ]
  // CF Property(TargetType) = "ip"
  // CF Property(VpcId) = aws_vpc.vpc.arn
}

resource "aws_wafv2_rule_group" "http_listener" {
  count = locals.CreateALB ? 1 : 0
  // CF Property(DefaultActions) = [
  //   {
  //     TargetGroupArn = aws_inspector_resource_group.default_http_target_group[0].arn
  //     Type = "forward"
  //   }
  // ]
  // CF Property(LoadBalancerArn) = aws_wafv2_regex_pattern_set.public_load_balancer[0].id
  // CF Property(Port) = 80
  // CF Property(Protocol) = "HTTP"
}

resource "aws_wafv2_rule_group" "https_listener" {
  count = locals.ExportHTTPSListener ? 1 : 0
  // CF Property(Certificates) = [
  //   {
  //     CertificateArn = aws_acm_certificate_validation.https_cert[0].id
  //   }
  // ]
  // CF Property(DefaultActions) = [
  //   {
  //     TargetGroupArn = aws_inspector_resource_group.default_http_target_group[0].arn
  //     Type = "forward"
  //   }
  // ]
  // CF Property(LoadBalancerArn) = aws_wafv2_regex_pattern_set.public_load_balancer[0].id
  // CF Property(Port) = 443
  // CF Property(Protocol) = "HTTPS"
}

resource "aws_wafv2_regex_pattern_set" "internal_load_balancer" {
  count = locals.CreateInternalALB ? 1 : 0
  // CF Property(Scheme) = "internal"
  // CF Property(SecurityGroups) = [
  //   aws_security_group.internal_load_balancer_security_group.id
  // ]
  // CF Property(Subnets) = [
  //   aws_subnet.private_subnet1.id,
  //   aws_subnet.private_subnet2.id
  // ]
  // CF Property(Type) = "application"
}

resource "aws_inspector_resource_group" "default_internal_http_target_group" {
  count = locals.CreateInternalALB ? 1 : 0
  // CF Property(HealthCheckIntervalSeconds) = 10
  // CF Property(HealthyThresholdCount) = 2
  // CF Property(HealthCheckTimeoutSeconds) = 5
  // CF Property(Port) = 80
  // CF Property(Protocol) = "HTTP"
  // CF Property(TargetGroupAttributes) = [
  //   {
  //     Key = "deregistration_delay.timeout_seconds"
  //     Value = 60
  //   }
  // ]
  // CF Property(TargetType) = "ip"
  // CF Property(VpcId) = aws_vpc.vpc.arn
}

resource "aws_wafv2_rule_group" "internal_http_listener" {
  count = locals.CreateInternalALB ? 1 : 0
  // CF Property(DefaultActions) = [
  //   {
  //     TargetGroupArn = aws_inspector_resource_group.default_internal_http_target_group[0].arn
  //     Type = "forward"
  //   }
  // ]
  // CF Property(LoadBalancerArn) = aws_wafv2_regex_pattern_set.internal_load_balancer[0].id
  // CF Property(Port) = 80
  // CF Property(Protocol) = "HTTP"
}

resource "aws_wafv2_rule_group" "internal_https_listener" {
  count = locals.ExportInternalHTTPSListener ? 1 : 0
  // CF Property(DefaultActions) = [
  //   {
  //     TargetGroupArn = aws_inspector_resource_group.default_internal_http_target_group[0].arn
  //     Type = "forward"
  //   }
  // ]
  // CF Property(LoadBalancerArn) = aws_wafv2_regex_pattern_set.internal_load_balancer[0].id
  // CF Property(Port) = 443
  // CF Property(Protocol) = "HTTPS"
}

resource "aws_efs_file_system" "file_system" {
  count = locals.CreateEFS ? 1 : 0
  // CF Property(BackupPolicy) = {
  //   Status = "ENABLED"
  // }
  encrypted = True
  // CF Property(FileSystemPolicy) = {
  //   Version = "2012-10-17"
  //   Id = "CopilotEFSPolicy"
  //   Statement = [
  //     {
  //       Sid = "AllowIAMFromTaggedRoles"
  //       Effect = "Allow"
  //       Principal = {
  //         AWS = "*"
  //       }
  //       Action = [
  //         "elasticfilesystem:ClientWrite",
  //         "elasticfilesystem:ClientMount"
  //       ]
  //       Condition = {
  //         Bool = {
  //           elasticfilesystem:AccessedViaMountTarget = True
  //         }
  //         StringEquals = {
  //           iam:ResourceTag/copilot-application = "${var.app_name}"
  //           iam:ResourceTag/copilot-environment = "${var.environment_name}"
  //         }
  //       }
  //     },
  //     {
  //       Sid = "DenyUnencryptedAccess"
  //       Effect = "Deny"
  //       Principal = "*"
  //       Action = "elasticfilesystem:*"
  //       Condition = {
  //         Bool = {
  //           aws:SecureTransport = False
  //         }
  //       }
  //     }
  //   ]
  // }
  lifecycle_policy = [
    {
      TransitionToIA = "AFTER_30_DAYS"
    }
  ]
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
}

resource "aws_security_group" "efs_security_group" {
  count = locals.CreateEFS ? 1 : 0
  description = join("", [var.app_name, "-", var.environment_name, "EFSSecurityGroup"])
  vpc_id = aws_vpc.vpc.arn
  tags = [
    {
      Key = "Name"
      Value = "copilot-${var.app_name}-${var.environment_name}-efs"
    }
  ]
}

resource "aws_security_group" "efs_security_group_ingress_from_environment" {
  count = locals.CreateEFS ? 1 : 0
  description = "Ingress from containers in the Environment Security Group."
  // CF Property(GroupId) = aws_security_group.efs_security_group[0].arn
  // CF Property(IpProtocol) = -1
  vpc_id = aws_security_group.environment_security_group.arn
}

resource "aws_efs_mount_target" "mount_target1" {
  count = locals.CreateEFS ? 1 : 0
  file_system_id = aws_efs_file_system.file_system[0].arn
  subnet_id = aws_subnet.private_subnet1.id
  security_groups = [
    aws_security_group.efs_security_group[0].arn
  ]
}

resource "aws_efs_mount_target" "mount_target2" {
  count = locals.CreateEFS ? 1 : 0
  file_system_id = aws_efs_file_system.file_system[0].arn
  subnet_id = aws_subnet.private_subnet2.id
  security_groups = [
    aws_security_group.efs_security_group[0].arn
  ]
}

resource "aws_iam_role" "cloudformation_execution_role" {
  name = "${local.stack_name}-CFNExecutionRole"
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "cloudformation.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "executeCfn"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            NotAction = [
              "organizations:*",
              "account:*"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "organizations:DescribeOrganization",
              "account:ListRegions"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_iam_role" "environment_manager_role" {
  name = "${local.stack_name}-EnvManagerRole"
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "${var.tools_account_principal_arn}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "root"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "CloudwatchLogs"
            Effect = "Allow"
            Action = [
              "logs:GetLogRecord",
              "logs:GetQueryResults",
              "logs:StartQuery",
              "logs:GetLogEvents",
              "logs:DescribeLogStreams",
              "logs:StopQuery",
              "logs:TestMetricFilter",
              "logs:FilterLogEvents",
              "logs:GetLogGroupFields",
              "logs:GetLogDelivery"
            ]
            Resource = "*"
          },
          {
            Sid = "Cloudwatch"
            Effect = "Allow"
            Action = [
              "cloudwatch:DescribeAlarms"
            ]
            Resource = "*"
          },
          {
            Sid = "ECS"
            Effect = "Allow"
            Action = [
              "ecs:ListAttributes",
              "ecs:ListTasks",
              "ecs:DescribeServices",
              "ecs:DescribeTaskSets",
              "ecs:ListContainerInstances",
              "ecs:DescribeContainerInstances",
              "ecs:DescribeTasks",
              "ecs:DescribeClusters",
              "ecs:UpdateService",
              "ecs:PutAttributes",
              "ecs:StartTelemetrySession",
              "ecs:StartTask",
              "ecs:StopTask",
              "ecs:ListServices",
              "ecs:ListTaskDefinitionFamilies",
              "ecs:DescribeTaskDefinition",
              "ecs:ListTaskDefinitions",
              "ecs:ListClusters",
              "ecs:RunTask"
            ]
            Resource = "*"
          },
          {
            Sid = "ExecuteCommand"
            Effect = "Allow"
            Action = [
              "ecs:ExecuteCommand"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                aws:ResourceTag/copilot-application = "${var.app_name}"
                aws:ResourceTag/copilot-environment = "${var.environment_name}"
              }
            }
          },
          {
            Sid = "CloudFormation"
            Effect = "Allow"
            Action = [
              "cloudformation:CancelUpdateStack",
              "cloudformation:CreateChangeSet",
              "cloudformation:CreateStack",
              "cloudformation:DeleteChangeSet",
              "cloudformation:DeleteStack",
              "cloudformation:Describe*",
              "cloudformation:DetectStackDrift",
              "cloudformation:DetectStackResourceDrift",
              "cloudformation:ExecuteChangeSet",
              "cloudformation:GetTemplate",
              "cloudformation:GetTemplateSummary",
              "cloudformation:UpdateStack",
              "cloudformation:UpdateTerminationProtection"
            ]
            Resource = "*"
          },
          {
            Sid = "GetAndPassCopilotRoles"
            Effect = "Allow"
            Action = [
              "iam:GetRole",
              "iam:PassRole"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                iam:ResourceTag/copilot-application = "${var.app_name}"
                iam:ResourceTag/copilot-environment = "${var.environment_name}"
              }
            }
          },
          {
            Sid = "ECR"
            Effect = "Allow"
            Action = [
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability",
              "ecr:CompleteLayerUpload",
              "ecr:DescribeImages",
              "ecr:DescribeRepositories",
              "ecr:GetDownloadUrlForLayer",
              "ecr:InitiateLayerUpload",
              "ecr:ListImages",
              "ecr:ListTagsForResource",
              "ecr:PutImage",
              "ecr:UploadLayerPart",
              "ecr:GetAuthorizationToken"
            ]
            Resource = "*"
          },
          {
            Sid = "ResourceGroups"
            Effect = "Allow"
            Action = [
              "resource-groups:GetGroup",
              "resource-groups:GetGroupQuery",
              "resource-groups:GetTags",
              "resource-groups:ListGroupResources",
              "resource-groups:ListGroups",
              "resource-groups:SearchResources"
            ]
            Resource = "*"
          },
          {
            Sid = "SSM"
            Effect = "Allow"
            Action = [
              "ssm:DeleteParameter",
              "ssm:DeleteParameters",
              "ssm:GetParameter",
              "ssm:GetParameters",
              "ssm:GetParametersByPath"
            ]
            Resource = "*"
          },
          {
            Sid = "SSMSecret"
            Effect = "Allow"
            Action = [
              "ssm:PutParameter",
              "ssm:AddTagsToResource"
            ]
            Resource = [
              "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/copilot/${var.app_name}/${var.environment_name}/secrets/*"
            ]
          },
          {
            Sid = "ELBv2"
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:DescribeLoadBalancerAttributes",
              "elasticloadbalancing:DescribeSSLPolicies",
              "elasticloadbalancing:DescribeLoadBalancers",
              "elasticloadbalancing:DescribeTargetGroupAttributes",
              "elasticloadbalancing:DescribeListeners",
              "elasticloadbalancing:DescribeTags",
              "elasticloadbalancing:DescribeTargetHealth",
              "elasticloadbalancing:DescribeTargetGroups",
              "elasticloadbalancing:DescribeRules"
            ]
            Resource = "*"
          },
          {
            Sid = "BuiltArtifactAccess"
            Effect = "Allow"
            Action = [
              "s3:ListBucketByTags",
              "s3:GetLifecycleConfiguration",
              "s3:GetBucketTagging",
              "s3:GetInventoryConfiguration",
              "s3:GetObjectVersionTagging",
              "s3:ListBucketVersions",
              "s3:GetBucketLogging",
              "s3:ListBucket",
              "s3:GetAccelerateConfiguration",
              "s3:GetBucketPolicy",
              "s3:GetObjectVersionTorrent",
              "s3:GetObjectAcl",
              "s3:GetEncryptionConfiguration",
              "s3:GetBucketRequestPayment",
              "s3:GetObjectVersionAcl",
              "s3:GetObjectTagging",
              "s3:GetMetricsConfiguration",
              "s3:HeadBucket",
              "s3:GetBucketPublicAccessBlock",
              "s3:GetBucketPolicyStatus",
              "s3:ListBucketMultipartUploads",
              "s3:GetBucketWebsite",
              "s3:ListJobs",
              "s3:GetBucketVersioning",
              "s3:GetBucketAcl",
              "s3:GetBucketNotification",
              "s3:GetReplicationConfiguration",
              "s3:ListMultipartUploadParts",
              "s3:GetObject",
              "s3:GetObjectTorrent",
              "s3:GetAccountPublicAccessBlock",
              "s3:ListAllMyBuckets",
              "s3:DescribeJob",
              "s3:GetBucketCORS",
              "s3:GetAnalyticsConfiguration",
              "s3:GetObjectVersionForReplication",
              "s3:GetBucketLocation",
              "s3:GetObjectVersion",
              "kms:Decrypt"
            ]
            Resource = "*"
          },
          {
            Sid = "PutObjectsToArtifactBucket"
            Effect = "Allow"
            Action = [
              "s3:PutObject",
              "s3:PutObjectAcl"
            ]
            Resource = [
              "arn:aws:s3:::stackset-ingestion-headl-pipelinebuiltartifactbuc-lz606a4kijla",
              "arn:aws:s3:::stackset-ingestion-headl-pipelinebuiltartifactbuc-lz606a4kijla/*"
            ]
          },
          {
            Sid = "EncryptObjectsInArtifactBucket"
            Effect = "Allow"
            Action = [
              "kms:GenerateDataKey"
            ]
            Resource = "arn:aws:kms:us-west-2:099132402094:key/d8ace00a-bbe8-450e-846e-5a92dbfdec37"
          },
          {
            Sid = "EC2"
            Effect = "Allow"
            Action = [
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DescribeRouteTables"
            ]
            Resource = "*"
          },
          {
            Sid = "AppRunner"
            Effect = "Allow"
            Action = [
              "apprunner:DescribeService",
              "apprunner:ListOperations",
              "apprunner:ListServices",
              "apprunner:PauseService",
              "apprunner:ResumeService",
              "apprunner:StartDeployment",
              "apprunner:DescribeObservabilityConfiguration"
            ]
            Resource = "*"
          },
          {
            Sid = "Tags"
            Effect = "Allow"
            Action = [
              "tag:GetResources"
            ]
            Resource = "*"
          },
          {
            Sid = "ApplicationAutoscaling"
            Effect = "Allow"
            Action = [
              "application-autoscaling:DescribeScalingPolicies"
            ]
            Resource = "*"
          },
          {
            Sid = "DeleteRoles"
            Effect = "Allow"
            Action = [
              "iam:DeleteRole",
              "iam:ListRolePolicies",
              "iam:DeleteRolePolicy"
            ]
            Resource = [
              aws_iam_role.cloudformation_execution_role.arn,
              "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.stack_name}-EnvManagerRole"
            ]
          },
          {
            Sid = "DeleteEnvStack"
            Effect = "Allow"
            Action = [
              "cloudformation:DescribeStacks",
              "cloudformation:DeleteStack"
            ]
            Resource = [
              "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/${local.stack_name}/*"
            ]
          }
        ]
      }
    }
  ]
}

resource "aws_iam_role" "custom_resource_role" {
  count = locals.DelegateDNS ? 1 : 0
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "DNSandACMAccess"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "acm:ListCertificates",
              "acm:RequestCertificate",
              "acm:DescribeCertificate",
              "acm:GetCertificate",
              "acm:DeleteCertificate",
              "acm:AddTagsToCertificate",
              "sts:AssumeRole",
              "logs:*",
              "route53:ChangeResourceRecordSets",
              "route53:Get*",
              "route53:Describe*",
              "route53:ListResourceRecordSets",
              "route53:ListHostedZonesByName"
            ]
            Resource = [
              "*"
            ]
          }
        ]
      }
    }
  ]
}

resource "aws_route" "environment_hosted_zone" {
  count = locals.DelegateDNS ? 1 : 0
  // CF Property(HostedZoneConfig) = {
  //   Comment = "HostedZone for environment ${var.environment_name} - ${var.environment_name}.${var.app_name}.${var.app_dns_name}"
  // }
  // CF Property(Name) = "${var.environment_name}.${var.app_name}.${var.app_dns_name}"
}

resource "aws_lambda_function" "certificate_validation_function" {
  count = locals.DelegateDNS ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = "stackset-ingestion-headl-pipelinebuiltartifactbuc-lz606a4kijla"
    S3Key = "manual/e76007690b4b1893cbfbd4be1163bb6e511645f665b082867bebba053d77779f/scripts/dns-cert-validator"
  }
  handler = "index.certificateRequestHandler"
  timeout = 900
  memory_size = 512
  role = aws_iam_role.custom_resource_role.arn
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "custom_domain_function" {
  count = locals.HasAliases ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = "stackset-ingestion-headl-pipelinebuiltartifactbuc-lz606a4kijla"
    S3Key = "manual/16e4534fdb25f2522fb3d68ec171db80ad33b0a0432da9f81fecc2f79dfe455b/scripts/custom-domain"
  }
  handler = "index.handler"
  timeout = 600
  memory_size = 512
  role = aws_iam_role.custom_resource_role.arn
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "dns_delegation_function" {
  count = locals.DelegateDNS ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = "stackset-ingestion-headl-pipelinebuiltartifactbuc-lz606a4kijla"
    S3Key = "manual/53149c09b76fa536ad519270831c32afd8649c3d9e6b49bafa079c57c51b3bec/scripts/dns-delegation"
  }
  handler = "index.domainDelegationHandler"
  timeout = 600
  memory_size = 512
  role = aws_iam_role.custom_resource_role.arn
  runtime = "nodejs12.x"
}

resource "aws_lambda_function_url" "delegate_dns_action" {
  count = locals.DelegateDNS ? 1 : 0
  // CF Property(ServiceToken) = aws_lambda_function.dns_delegation_function.arn
  // CF Property(DomainName) = "${var.app_name}.${var.app_dns_name}"
  // CF Property(SubdomainName) = "${var.environment_name}.${var.app_name}.${var.app_dns_name}"
  // CF Property(RootDNSRole) = var.app_dns_delegation_role
}

resource "aws_acm_certificate_validation" "https_cert" {
  count = locals.DelegateDNS ? 1 : 0
  // CF Property(ServiceToken) = aws_lambda_function.certificate_validation_function.arn
  // CF Property(AppName) = var.app_name
  // CF Property(EnvName) = var.environment_name
  // CF Property(DomainName) = var.app_dns_name
  // CF Property(Aliases) = var.aliases
  // CF Property(EnvHostedZoneId) = aws_route.environment_hosted_zone[0].id
  // CF Property(Region) = data.aws_region.current.name
  // CF Property(RootDNSRole) = var.app_dns_delegation_role
}

resource "aws_lambda_function_url" "custom_domain_action" {
  count = locals.HasAliases ? 1 : 0
  // CF Property(ServiceToken) = aws_lambda_function.custom_domain_function.arn
  function_name = var.environment_name
  // CF Property(Aliases) = var.aliases
  // CF Property(AppDNSRole) = var.app_dns_delegation_role
  // CF Property(DomainName) = var.app_dns_name
  // CF Property(LoadBalancerDNS) = aws_wafv2_regex_pattern_set.public_load_balancer.name
  // CF Property(LoadBalancerHostedZone) = aws_wafv2_regex_pattern_set.public_load_balancer.id
}

output "vpc_id" {
  value = aws_vpc.vpc.arn
}

output "public_subnets" {
  value = join(",", [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id])
}

output "private_subnets" {
  value = join(",", [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id])
}

output "internet_gateway_id" {
  value = aws_internet_gateway.internet_gateway.id
}

output "public_route_table_id" {
  value = aws_route_table.public_route_table.id
}

output "private_route_table_i_ds" {
  value = join(",", [aws_route_table.private_route_table1[0].id, aws_route_table.private_route_table2[0].id])
}

output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.service_discovery_namespace.id
}

output "environment_security_group" {
  value = aws_security_group.environment_security_group.arn
}

output "public_load_balancer_dns_name" {
  value = aws_wafv2_regex_pattern_set.public_load_balancer.name
}

output "public_load_balancer_full_name" {
  value = aws_wafv2_regex_pattern_set.public_load_balancer.name
}

output "public_load_balancer_hosted_zone" {
  value = aws_wafv2_regex_pattern_set.public_load_balancer.id
}

output "http_listener_arn" {
  value = aws_wafv2_rule_group.http_listener[0].id
}

output "https_listener_arn" {
  value = aws_wafv2_rule_group.https_listener[0].id
}

output "default_http_target_group_arn" {
  value = aws_inspector_resource_group.default_http_target_group[0].arn
}

output "internal_load_balancer_dns_name" {
  value = aws_wafv2_regex_pattern_set.internal_load_balancer.name
}

output "internal_load_balancer_full_name" {
  value = aws_wafv2_regex_pattern_set.internal_load_balancer.name
}

output "internal_load_balancer_hosted_zone" {
  value = aws_wafv2_regex_pattern_set.internal_load_balancer.id
}

output "internal_http_listener_arn" {
  value = aws_wafv2_rule_group.internal_http_listener[0].id
}

output "internal_https_listener_arn" {
  value = aws_wafv2_rule_group.internal_https_listener[0].id
}

output "internal_load_balancer_security_group" {
  value = aws_security_group.internal_load_balancer_security_group[0].arn
}

output "cluster_id" {
  value = aws_ecs_cluster.cluster.arn
}

output "environment_manager_role_arn" {
  description = "The role to be assumed by the ecs-cli to manage environments."
  value = aws_iam_role.environment_manager_role.arn
}

output "cfn_execution_role_arn" {
  description = "The role to be assumed by the Cloudformation service when it deploys application infrastructure."
  value = aws_iam_role.cloudformation_execution_role.arn
}

output "environment_hosted_zone" {
  description = "The HostedZone for this environment's private DNS."
  value = aws_route.environment_hosted_zone[0].id
}

output "environment_subdomain" {
  description = "The domain name of this environment."
  value = "${var.environment_name}.${var.app_name}.${var.app_dns_name}"
}

output "enabled_features" {
  description = "Required output to force the stack to update if mutating feature params, like ALBWorkloads, does not change the template."
  value = "${var.alb_workloads},${var.internal_alb_workloads},${var.efs_workloads},${var.nat_workloads}"
}

output "managed_file_system_id" {
  description = "The ID of the Copilot-managed EFS filesystem."
  value = aws_efs_file_system.file_system[0].arn
}
