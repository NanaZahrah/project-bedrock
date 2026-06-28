output "lambda_arn"           { value = aws_lambda_function.main.arn }
output "lambda_function_name" { value = aws_lambda_function.main.function_name }
output "lambda_permission_id" { value = aws_lambda_permission.s3_invoke.id }
