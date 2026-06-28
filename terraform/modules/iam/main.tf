resource "aws_iam_user_policy" "dev_s3_put" {
  name = "bedrock-dev-s3-put"
  user = var.dev_user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${var.assets_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_user_policy_attachment" "dev_readonly" {
  user       = var.dev_user_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
