# --- NETWORKING FOR ECS (Cost-Optimized, Public Subnet Only) ---
resource "aws_vpc" "ecs_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ecs-vpc-${data.aws_region.current.name}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_vpc.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}a"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecs_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security group allowing outbound traffic
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-task-sg-${data.aws_region.current.name}"
  description = "Allow outbound traffic for ECS task"
  vpc_id      = aws_vpc.ecs_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS CLUSTER ---
resource "aws_ecs_cluster" "cluster" {
  name = "unleash-cluster-${data.aws_region.current.name}"
}

# --- ECS IAM ROLES ---
# Execution Role: Allow ECS agent to pull image and write logs
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-exec-role-${data.aws_region.current.name}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role: Allow container to publish to SNS
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role-${data.aws_region.current.name}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "ecs_task_sns_policy" {
  name = "ecs-task-sns-policy"
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["sns:Publish"]
      Effect   = "Allow"
      Resource = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
    }]
  })
}

# --- ECS TASK DEFINITION ---
resource "aws_ecs_task_definition" "sns_task" {
  family                   = "sns-publisher-${data.aws_region.current.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Minimal cost
  memory                   = "512" # Minimal cost
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn


  container_definitions = jsonencode([{
    name      = "aws-cli-publisher"
    image     = "amazon/aws-cli:latest"
    essential = true
    command = [
      "sns", "publish",
      "--topic-arn", "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic",
      "--message", jsonencode({
        email  = var.candidate_email
        source = "ECS"
        region = data.aws_region.current.name
        repo   = var.github_repo
      }),
      "--region", "us-east-1"
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/sns-publisher-${data.aws_region.current.name}"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
        "awslogs-create-group"  = "true"
      }
    }
  }])
}