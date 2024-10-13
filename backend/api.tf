# IAM Role for Backend Lambda
resource "aws_iam_role" "lambda_role" {
  name = "backend_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Policy to allow Lambda to interact with SQS and RDS
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "${aws_dynamodb_table.guesses.arn}",
          "${aws_dynamodb_table.guesses.arn}/index/*"
        ]
      },
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.guesses.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_function" "api-handler" {
  function_name    = "api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "app.app"
  runtime          = "python3.9"
  filename         = "lambda/api/deploy/deployment.zip"
  source_code_hash = filebase64sha256("lambda/api/deploy/deployment.zip")
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.guesses.name
      SQS_QUEUE_URL  = aws_sqs_queue.guesses.id
    }
  }
  memory_size = 128 # Keep memory size low to stay within free tier
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.api-handler.function_name}"
  retention_in_days = 7
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name = "lambda_logging_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.api-handler.function_name}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}