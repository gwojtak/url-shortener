data "aws_iam_policy_document" "lambda_trust" {
  statement {
    sid     = "LambdaTrustPolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "ddb_access" {
  statement {
    sid    = "DynamoDBURLShortenerTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:PutItem"
    ]
    resources = [aws_dynamodb_table.urls.arn]
  }
}

resource "aws_iam_policy" "ddb_access" {
  name        = "URLShortenerDynamoDBAccessPolicy"
  description = "Allow Lambda to perform reads on DynamoDB table for url shortener"
  policy      = data.aws_iam_policy_document.ddb_access.json
}

resource "aws_iam_role" "lambda_ddb_access" {
  name               = "URLShortenerDynamoDBAccessRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "ddb_role_policy" {
  role       = aws_iam_role.lambda_ddb_access.name
  policy_arn = aws_iam_policy.ddb_access.arn
}


resource "aws_lambda_function" "get_url_by_id" {
  function_name    = "GetURLByID"
  description      = "Gets a long url by ID (short URL) from DynamoDB"
  role             = aws_iam_role.lambda_ddb_access.arn
  runtime          = "python3.9"
  filename         = "../lambda_src/get_url.zip"
  handler          = "get_url.handler"
  source_code_hash = filebase64sha256("../lambda_src/get_url.zip")
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_url_by_id.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_function" "post_url" {
  function_name    = "PostURL"
  description      = "Create a new shortened URL entry"
  role             = aws_iam_role.lambda_ddb_access.arn
  runtime          = "python3.9"
  filename         = "../lambda_src/post_url.zip"
  handler          = "post_url.handler"
  source_code_hash = filebase64sha256("../lambda_src/post_url.zip")
}

resource "aws_lambda_permission" "apigw_lambda_post" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_url.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "null_resource" "zip" {
  for_each = toset(fileset("../lambda_src/", "*.py"))

  provisioner "local-exec" {
    command     = "zip ${trimsuffix(each.value, ".py")}.zip ${each.value}"
    working_dir = "../lambda_src"
  }
}
