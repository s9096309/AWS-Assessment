# --- DYNAMODB ---
resource "aws_dynamodb_table" "greeting_logs" {
  name           = "GreetingLogs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# --- IAM ROLE FOR LAMBDA 1 (GREETER) ---
resource "aws_iam_role" "lambda_greeter_role" {
  name = "lambda-greeter-role-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_greeter_policy" {
  name = "lambda-greeter-policy"
  role = aws_iam_role.lambda_greeter_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Basic execution (CloudWatch Logs)
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # DynamoDB write permissions
        Action   = ["dynamodb:PutItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.greeting_logs.arn
      },
      {
        # Unleash live SNS Topic publish permissions
        Action   = ["sns:Publish"]
        Effect   = "Allow"
        Resource = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
      }
    ]
  })
}

# --- PACKAGE LAMBDA CODE ---
data "archive_file" "greeter_zip" {
  type        = "zip"
  source_file = "${path.module}/src/greeter.py"
  output_path = "${path.module}/greeter_payload.zip"
}

# --- LAMBDA 1 (THE GREETER) ---
resource "aws_lambda_function" "greeter" {
  function_name = "unleash-greeter-${data.aws_region.current.name}"
  
  # Attach IAM role created in previous step
  role          = aws_iam_role.lambda_greeter_role.arn
  
  handler       = "greeter.lambda_handler"
  runtime       = "python3.12"
  
  # Reference zipped payload
  filename         = data.archive_file.greeter_zip.output_path
  source_code_hash = data.archive_file.greeter_zip.output_base64sha256
  
  # keep timeouts short
  timeout       = 10

  # Inject environment variables expected by the Python script
  environment {
    variables = {
      CANDIDATE_EMAIL = var.candidate_email
      GITHUB_REPO     = var.github_repo
      TABLE_NAME      = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN   = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
    }
  }
}

# --- IAM ROLE FOR LAMBDA 2 (DISPATCHER) ---
resource "aws_iam_role" "lambda_dispatcher_role" {
  name = "lambda-dispatcher-role-${data.aws_region.current.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_dispatcher_policy" {
  name = "lambda-dispatcher-policy"
  role = aws_iam_role.lambda_dispatcher_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = ["ecs:RunTask"]
        Effect   = "Allow"
        # Append a wildcard so IAM allows execution of any revision (e.g., :1, :2, etc.)
        Resource = "${aws_ecs_task_definition.sns_task.arn_without_revision}:*"
      },
      {
        # Required to pass the execution and task roles to the ECS task
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = [aws_iam_role.ecs_execution_role.arn, aws_iam_role.ecs_task_role.arn]
      }
    ]
  })
}

# --- PACKAGE DISPATCHER LAMBDA ---
data "archive_file" "dispatcher_zip" {
  type        = "zip"
  source_file = "${path.module}/src/dispatcher.py"
  output_path = "${path.module}/dispatcher_payload.zip"
}

# --- LAMBDA 2 (THE DISPATCHER) ---
resource "aws_lambda_function" "dispatcher" {
  function_name    = "unleash-dispatcher-${data.aws_region.current.name}"
  role             = aws_iam_role.lambda_dispatcher_role.arn
  handler          = "dispatcher.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.dispatcher_zip.output_path
  source_code_hash = data.archive_file.dispatcher_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      CLUSTER_NAME      = aws_ecs_cluster.cluster.name
      TASK_DEFINITION   = aws_ecs_task_definition.sns_task.family
      SUBNET_ID         = aws_subnet.public_subnet.id
      SECURITY_GROUP_ID = aws_security_group.ecs_sg.id
    }
  }
}