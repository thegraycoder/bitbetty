provider "aws" {
  region = "eu-central-1" # Change this to your preferred region
}

# Outputs
output "post_guesses_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}${aws_api_gateway_stage.prod.stage_name}/guesses"
}

output "get_scores_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}${aws_api_gateway_stage.prod.stage_name}/scores"
}