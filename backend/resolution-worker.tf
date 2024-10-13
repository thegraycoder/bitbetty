# IAM Role for Backend Lambda
resource "aws_iam_role" "worker_lambda_role" {
  name = "worker_lambda_role"
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
resource "aws_iam_policy" "worker_lambda_policy" {
  name = "worker_lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "dynamodb:UpdateItem",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
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
          "sqs:ChangeMessageVisibility",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.guesses.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_lambda_policy_attachment" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = aws_iam_policy.worker_lambda_policy.arn
}


resource "aws_lambda_function" "worker" {
  function_name    = "resolution-worker"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.handle_guesses"
  runtime          = "python3.9"
  filename         = "lambda/resolution-worker/deploy/deployment.zip"
  source_code_hash = filebase64sha256("lambda/resolution-worker/deploy/deployment.zip")
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.guesses.name
      SQS_QUEUE_URL  = aws_sqs_queue.guesses.id
    }
  }
  memory_size = 128 # Keep memory size low to stay within free tier
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.guesses.arn
  function_name    = aws_lambda_function.worker.function_name
  enabled          = true
  batch_size       = 10
}

resource "aws_cloudwatch_log_group" "worker_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.worker.function_name}"
  retention_in_days = 7
}

resource "aws_iam_policy" "worker_lambda_logging_policy" {
  name = "worker_lambda_logging_policy"
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
          "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.worker.function_name}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_lambda_logging_policy_attachment" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = aws_iam_policy.worker_lambda_logging_policy.arn
}