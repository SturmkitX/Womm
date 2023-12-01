resource "aws_ecs_cluster" "womm-ecs-cluster" {
  name = "womm-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "womm-nginx-task-def" {
  family = "service"
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  cpu       = 256
  memory    = 512
  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:1.25.3-alpine"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      healthCheck = {
        retries = 10
        command = [ "CMD-SHELL", "curl -f http://localhost || exit 1" ]
        timeout = 5
        interval = 10
        startPeriod = 5
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }

#   placement_constraints {
#     type       = "memberOf"
#     expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
#   }
}

resource "aws_security_group" "womm-ecs-sg" {
  name    = "womm-ecs-sg-01"
  vpc_id  = aws_vpc.womm-vpc-01.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
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

resource "aws_ecs_service" "womm-nginx-service" {
  name            = "nginx"
  cluster         = aws_ecs_cluster.womm-ecs-cluster.id
  task_definition = aws_ecs_task_definition.womm-nginx-task-def.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets = [ aws_subnet.womm-subnet-01.id ]
    security_groups = [ aws_security_group.womm-ecs-sg.id ]
  }
#   iam_role        = aws_iam_role.foo.arn
#   depends_on      = [aws_iam_role_policy.foo]

#   ordered_placement_strategy {
#     type  = "binpack"
#     field = "cpu"
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.foo.arn
#     container_name   = "mongo"
#     container_port   = 8080
#   }

#   placement_constraints {
#     type       = "memberOf"
#     expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
#   }
}

# resource "aws_ecs_cluster_capacity_providers" "womm-cluster-capacity-provider" {
#   cluster_name = aws_ecs_cluster.womm-ecs-cluster.name

#   capacity_providers = ["FARGATE_SPOT", "FARGATE"]

#   default_capacity_provider_strategy {
#     base              = 1
#     weight            = 100
#     capacity_provider = "FARGATE_SPOT"
#   }
# }

resource "aws_eip" "gw-eip" {
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "womm-nat" {
  allocation_id = aws_eip.gw-eip.id
  subnet_id     = aws_subnet.womm-subnet-01.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
#   depends_on = [aws_internet_gateway.example]
}