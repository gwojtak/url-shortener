resource "aws_dynamodb_table" "urls" {
  name         = "URLTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "userid"
    type = "S"
  }

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "url"
    type = "S"
  }

  attribute {
    name = "created"
    type = "S"
  }

  global_secondary_index {
    name               = "url_index"
    hash_key           = "url"
    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }

  global_secondary_index {
    name               = "userid_index"
    hash_key           = "userid"
    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }

  global_secondary_index {
    name               = "created_index"
    hash_key           = "created"
    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }
}

resource "aws_dynamodb_table_item" "test_data" {
  table_name = aws_dynamodb_table.urls.name
  hash_key   = aws_dynamodb_table.urls.hash_key
  item = jsonencode({
    id = {
      S = "abcd123"
    },
    url = {
      S = "https://google.com"
    },
    userid = {
      S = "gwojtak"
    },
    created = {
      S = "20220402120200"
    }
  })
}
