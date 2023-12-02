data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
        "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "lambda_config" {
  statement {
    effect = "Allow"

    resources = [ "*" ]

    actions = [
        "ec2:DescribeInstances",
        "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        # "autoscaling:CompleteLifecycleAction",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
    ]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.iam_for_lambda.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = data.aws_iam_policy_document.lambda_config.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.js"
  output_path = "lambda_function_payload.zip"
}

resource "aws_security_group" "lambda-sg" {
  name    = "lambda-sg-01"
  vpc_id  = aws_vpc.womm-vpc-01.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

#   ingress {
#     description      = "Ping"
#     protocol         = "icmp"
#     from_port        = -1
#     to_port          = -1
#     cidr_blocks      = ["0.0.0.0/0"]
#   }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_function_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"

  vpc_config {
    subnet_ids = [ aws_subnet.womm-subnet-01.id ]
    security_group_ids = [ aws_security_group.lambda-sg.id ]
  }

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_lambda_function_url" "test_latest" {
  function_name      = aws_lambda_function.test_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

output "lambda_url" {
  description = "Lambda function URL"
  value = aws_lambda_function_url.test_latest.function_url
}
