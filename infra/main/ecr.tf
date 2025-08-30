resource "aws_ecr_repository" "tasky" {
  name = "${var.name_prefix}-tasky"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
