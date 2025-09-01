resource "aws_s3_bucket" "mongo_backups" {
  bucket        = var.backup_bucket
  force_destroy = true
}

# Disable public access blocks to allow public policy
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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
  
  depends_on = [aws_s3_bucket_public_access_block.mongo_backups]
}
