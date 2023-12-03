data "aws_iam_policy_document" "vpn_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = [
        "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "ec2_container_config" {
  statement {
    effect = "Allow"

    resources = [ "*" ]

    actions = [
        "ec2:DescribeTags",
				"ecs:DeregisterContainerInstance",
				"ecs:DiscoverPollEndpoint",
				"ecs:Poll",
				"ecs:RegisterContainerInstance",
				"ecs:StartTelemetrySession",
				"ecs:UpdateContainerInstancesState",
				"ecs:Submit*",
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:GetDownloadUrlForLayer",
				"ecr:BatchGetImage",
				"logs:CreateLogStream",
				"logs:PutLogEvents"
    ]
  }
}

resource "aws_iam_role" "iam_for_ec2_container" {
  name               = "iam_for_ec2_container"
  assume_role_policy = data.aws_iam_policy_document.vpn_assume_role.json
}

resource "aws_iam_role_policy" "vpn_policy" {
  name = "vpn_policy"
  role = aws_iam_role.iam_for_ec2_container.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = data.aws_iam_policy_document.ec2_container_config.json
}

resource "aws_iam_instance_profile" "vpn_profile" {
  name = "vpn_profile"
  role = aws_iam_role.iam_for_ec2_container.name
}

resource "aws_ecs_cluster" "womm-ecs-ec2-cluster" {
  name = "womm-ec2-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_launch_template" "example" {
  name_prefix   = "example"
  # image_id      = "ami-064087b8d355e9051"
  image_id = "ami-0303c7e50922dfc1c"  # Amazon ECS-optimized Amazon Linux 2023 AMI
  instance_type = "t3.large"
  network_interfaces {
    subnet_id = aws_subnet.womm-subnet-public.id
    security_groups = [ aws_security_group.womm-vpn-sg.id ]
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.vpn_profile.arn
  }

  user_data = filebase64("example.sh")
}

resource "aws_autoscaling_group" "example" {
  capacity_rebalance  = true
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.womm-subnet-public.id]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.example.id
      }
    }
  }
}


resource "aws_ecs_task_definition" "womm-vpn-task-def" {
  family = "service"
  network_mode = "awsvpc"
  # requires_compatibilities = [ "EC2" ]
  cpu       = 1024
  memory    = 2048
  container_definitions = jsonencode([
    {
      name      = "wireguard"
      image     = "lscr.io/linuxserver/wireguard:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 51820
          hostPort      = 51820
          protocol      = "udp"
        }
      ]
      healthCheck = {
        retries = 10
        command = [ "CMD-SHELL", "exit 0" ]
        timeout = 5
        interval = 10
        startPeriod = 5
      }
      systemControls = [
        {
            namespace = "net.ipv4.conf.all.src_valid_mark"
            value     = "1"
        }
      ]
      linuxParameters = {
        capabilities = {
            add = [ "NET_ADMIN", "SYS_MODULE" ]
        }
      }
      environment = [
        {
            name = "PUID"
            value = "1000"
        },
        {
            name = "PGID"
            value = "1000"
        },
        {
            name = "TZ"
            value = "Etc/UTC"
        },
        {
            name = "PEERS"
            value = "5"
        },
        {
            name = "LOG_CONFS"
            value = "true"
        }
      ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }
}

resource "aws_security_group" "womm-vpn-sg" {
  name    = "womm-vpn-sg-01"
  vpc_id  = aws_vpc.womm-vpc-01.id

  ingress {
    description      = "Wireguard UDP"
    from_port        = 51820
    to_port          = 51820
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Ping"
    protocol         = "icmp"
    from_port        = -1
    to_port          = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster_capacity_providers" "womm-cluster-ec2-capacity-provider" {
  cluster_name = aws_ecs_cluster.womm-ecs-ec2-cluster.name

  capacity_providers = [aws_ecs_capacity_provider.test.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.test.name
  }
}

resource "aws_ecs_service" "womm-vpn-service" {
  name            = "wireguard"
  cluster         = aws_ecs_cluster.womm-ecs-ec2-cluster.id
  task_definition = aws_ecs_task_definition.womm-vpn-task-def.id
  desired_count   = 1
  # launch_type     = "EC2"
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.test.name
    weight = 100
  }
  network_configuration {
    subnets = [ aws_subnet.womm-subnet-public.id ]
    security_groups = [ aws_security_group.womm-vpn-sg.id ]
  }
}