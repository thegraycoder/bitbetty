resource "aws_dynamodb_table" "guesses" {
  name         = "guesses"
  billing_mode = "PAY_PER_REQUEST" # On-demand capacity mode, no need to manage RCU/WCU
  hash_key     = "id"              # Partition key for the table

  attribute {
    name = "id"
    type = "S" # String
  }

  attribute {
    name = "username"
    type = "S" # String, for GSI
  }

  # Global Secondary Index (GSI) for querying by username
  global_secondary_index {
    name            = "username-index"
    hash_key        = "username"
    projection_type = "ALL" # Include all attributes in the index
  }
}