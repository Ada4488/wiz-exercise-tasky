output "cluster_name" { value = module.eks.cluster_name }
output "ecr_repo_url" { value = aws_ecr_repository.tasky.repository_url }
output "mongo_private_ip" { value = aws_instance.mongo.private_ip }
output "mongo_public_ip" { value = aws_instance.mongo.public_ip }
output "vpc_id" { value = module.vpc.vpc_id }
