resource "aws_s3_bucket" "mongo_backups" {
  bucket        = var.backup_bucket
  force_destroy = true
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.mongo_backups.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "PublicList", Effect = "Allow", Principal = "*", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::${aws_s3_bucket.mongo_backups.bucket}" },
      { Sid = "PublicRead", Effect = "Allow", Principal = "*", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::${aws_s3_bucket.mongo_backups.bucket}/*" }
    ]
  })
}
