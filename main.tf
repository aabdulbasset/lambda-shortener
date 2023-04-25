terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-3"
}

resource "aws_db_instance" "default1" {
  allocated_storage       = 10
  db_name                 = "default1"
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  username                = "postgres"
  password                = "3Vzo4n6D4m5b"
  skip_final_snapshot     = true
  publicly_accessible     = true
  backup_retention_period = 0


}

resource "aws_lambda_function" "makeLink" {
  function_name = "makeLink"
  handler       = "makeLink.create_shorturl"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  filename      = "makeLink.zip"
  environment {
    variables = {
      "DATABASE_URL" = "postgres://postgres:${aws_db_instance.default1.password}@${aws_db_instance.default1.endpoint}/default1"
    }
  }
}
resource "aws_lambda_function" "redirect" {
  function_name = "redirect"
  handler       = "redirect.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  filename      = "redirect.zip"
  environment {
    variables = {
      "DATABASE_URL" = "postgres://postgres:${aws_db_instance.default1.password}@${aws_db_instance.default1.endpoint}/default1"
    }
  }
}

resource "aws_lambda_function" "allStats" {
  function_name = "allStats"
  handler       = "allstats.all_links"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  filename      = "allStats.zip"
  environment {
    variables = {
      "DATABASE_URL" = "postgres://postgres:${aws_db_instance.default1.password}@${aws_db_instance.default1.endpoint}/default1"
    }
  }
}

resource "aws_lambda_function" "singleStat" {
  function_name = "singleStats"
  handler       = "stats.short_stats"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  filename      = "stats.zip"
  environment {
    variables = {
      "DATABASE_URL" = "postgres://postgres:${aws_db_instance.default1.password}@${aws_db_instance.default1.endpoint}/default1"
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


