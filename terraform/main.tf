# =============================================================
# Projekt 5 - Complete Fargate Stack as Code
# Docker + ECR + ECS Fargate, provisioned with Terraform
# Author: Mehdi Mohammadi | Region: eu-central-1 (Frankfurt)
# =============================================================

provider "aws" {
  region = "eu-central-1"
}

# -------------------------------------------------------------
# Existing resources (referenced, not created)
# -------------------------------------------------------------

# Default VPC and its subnets - kept simple for this project.
# In production I would create a dedicated VPC with private
# subnets and a NAT gateway or VPC endpoints.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# The ECR repository already exists (images pushed by the
# GitHub Actions pipeline), so we reference it instead of
# creating a new one.
data "aws_ecr_repository" "app" {
  name = "project5-app"
}

# -------------------------------------------------------------
# S3 (kept from the initial Terraform test)
# -------------------------------------------------------------

resource "aws_s3_bucket" "mein_bucket" {
  bucket = "mehdi-terraform-projekt5-2026"

  tags = {
    Name    = "Terraform Test Bucket"
    Projekt = "Projekt 5"
  }
}

# -------------------------------------------------------------
# Logging
# -------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/projekt5-tf"
  retention_in_days = 7

  tags = {
    Projekt = "Projekt 5"
  }
}

# -------------------------------------------------------------
# IAM - Task Execution Role
# Used by ECS itself to pull the image from ECR and write logs.
# Least privilege: only the AWS-managed execution policy.
# -------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "projekt5-tf-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Projekt = "Projekt 5"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------------------------------------------------
# Networking - Security Group
# Only the app port is open for inbound traffic.
# -------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "projekt5-tf-sg"
  description = "Allow inbound traffic to the app container"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App port"
    from_port   = 3000 # ANPASSEN: Port aus deinem Dockerfile (EXPOSE)
    to_port     = 3000 # ANPASSEN: gleicher Port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Projekt = "Projekt 5"
  }
}

# -------------------------------------------------------------
# ECS - Cluster, Task Definition, Service
# -------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "projekt5-cluster-tf"

  tags = {
    Projekt = "Projekt 5"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "projekt5-tf-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${data.aws_ecr_repository.app.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3000 # ANPASSEN: Port aus deinem Dockerfile
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = "eu-central-1"
        awslogs-stream-prefix = "app"
      }
    }
  }])

  tags = {
    Projekt = "Projekt 5"
  }
}

# desired_count = 0 on purpose: the full stack exists as code
# and can be scaled up with one change - but idle it costs $0.
# Cost awareness is part of good cloud architecture.
resource "aws_ecs_service" "app" {
  name            = "projekt5-tf-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true # needed to pull from ECR without a NAT gateway
  }

  tags = {
    Projekt = "Projekt 5"
  }
}

# -------------------------------------------------------------
# Outputs
# -------------------------------------------------------------

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  value = data.aws_ecr_repository.app.repository_url
}
