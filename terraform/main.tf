terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# -------------------
# VPC (simple, single‑AZ)
# -------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "fargate-demo-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "fargate-demo-public"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "fargate-demo-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "fargate-demo-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------------------
# IAM Roles for ECS Task Execution
# -------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permission for DynamoDB access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "DynamoDBAccessPolicy"
  description = "Allow read/write on the demo table"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan", "dynamodb:Query"],
      Resource = aws_dynamodb_table.items.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# -------------------
# DynamoDB Table
# -------------------
resource "aws_dynamodb_table" "items" {
  name           = "DemoItems"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Environment = "dev"
  }
}

# -------------------
# ECS Cluster & Service
# -------------------
resource "aws_ecs_cluster" "demo" {
  name = "fargate-demo-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "fargate-demo-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 5000, protocol = "tcp" }]
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.items.name }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "fargate-demo-service"
  cluster         = aws_ecs_cluster.demo.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = [aws_subnet.public.id]
    assign_public_ip = true
    security_groups = [aws_security_group.sg.id]
  }
  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution]
}

# -------------------
# Security Group (allow inbound 80/443)
# -------------------
resource "aws_security_group" "sg" {
  name        = "fargate-demo-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# ECR Repository
# -------------------
resource "aws_ecr_repository" "app" {
  name = "aws-fargate-ci-cd-demo"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Environment = "dev"
  }
}
