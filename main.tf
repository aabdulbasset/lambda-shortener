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


resource "aws_api_gateway_rest_api" "lambda_api" {
  name = "lambda_api"
}

resource "aws_api_gateway_method" "new_link_method" {
  authorization    = "NONE"
  http_method      = "POST"
  resource_id      = aws_api_gateway_rest_api.lambda_api.root_resource_id
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  api_key_required = true
}
resource "aws_api_gateway_integration" "new_link_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda_api.id
  resource_id             = aws_api_gateway_rest_api.lambda_api.root_resource_id
  http_method             = aws_api_gateway_method.new_link_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.makeLink.invoke_arn
}
resource "aws_api_gateway_resource" "redirect" {
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "{shorturl+}"
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
}
resource "aws_api_gateway_method" "redirect_method" {
  authorization    = "NONE"
  http_method      = "GET"
  resource_id      = aws_api_gateway_resource.redirect.id
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  api_key_required = false
}
resource "aws_api_gateway_integration" "redirect_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda_api.id
  resource_id             = aws_api_gateway_resource.redirect.id
  http_method             = aws_api_gateway_method.redirect_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.redirect.invoke_arn
}
resource "aws_api_gateway_resource" "stats" {
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "stats"
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
}
resource "aws_api_gateway_resource" "stat" {
  parent_id   = aws_api_gateway_resource.stats.id
  path_part   = "{shorturl+}"
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
}
resource "aws_api_gateway_method" "stats_method" {
  authorization    = "NONE"
  http_method      = "GET"
  resource_id      = aws_api_gateway_resource.stats.id
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  api_key_required = true
}
resource "aws_api_gateway_method" "stat_method" {
  authorization    = "NONE"
  http_method      = "GET"
  resource_id      = aws_api_gateway_resource.stat.id
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  api_key_required = true
}
resource "aws_api_gateway_integration" "stats_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda_api.id
  resource_id             = aws_api_gateway_resource.stats.id
  http_method             = aws_api_gateway_method.stats_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.allStats.invoke_arn
}
resource "aws_api_gateway_integration" "stat_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda_api.id
  resource_id             = aws_api_gateway_resource.stat.id
  http_method             = aws_api_gateway_method.stat_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.singleStat.invoke_arn
}
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.redirect.id,
      aws_api_gateway_method.redirect_method.id,
      aws_api_gateway_integration.redirect_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  stage_name    = "v1"
}

resource "aws_lambda_permission" "redirect_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}
resource "aws_lambda_permission" "singleStat_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.singleStat.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}
resource "aws_lambda_permission" "allStats_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.allStats.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}
resource "aws_lambda_permission" "makeLink_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.makeLink.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}
