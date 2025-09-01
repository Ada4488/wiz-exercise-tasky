# Use Ubuntu 18.04 (1+ year outdated) as required by exercise
data "aws_ssm_parameter" "ubuntu1804_ami" {
  name = "/aws/service/canonical/ubuntu/server/18.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_security_group" "mongo" {
  name   = "${var.name_prefix}-mongo-sg"
  vpc_id = module.vpc.vpc_id

  # Allow SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow MongoDB access from private subnets
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = concat(module.vpc.private_subnets_cidr_blocks)
  }

  # Allow all egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "kp" {
  key_name   = "${var.name_prefix}-kp"
  public_key = var.ec2_ssh_public_key
}

# Overly permissive instance role (as required by exercise)
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-mongo-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

# AdministratorAccess policy (overly permissive as required)
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Additional overly permissive policy for VM creation (as required)
resource "aws_iam_role_policy" "vm_creation" {
  name = "${var.name_prefix}-vm-creation-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "iam:*",
          "s3:*",
          "eks:*",
          "rds:*",
          "lambda:*"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-mongo-profile"
  role = aws_iam_role.ec2_role.name
}

locals {
  backup_cron = <<EOT
0 2 * * * root mongodump --archive=/tmp/mongodump.archive --gzip --username wiz --password "WizPass123!" --authenticationDatabase admin && aws s3 cp /tmp/mongodump.archive s3://${aws_s3_bucket.mongo_backups.bucket}/mongodump-$(date +\\%F).archive.gz --content-type application/gzip
EOT
}

resource "aws_instance" "mongo" {
  ami                    = data.aws_ssm_parameter.ubuntu1804_ami.value
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.mongo.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.kp.key_name

  tags = { Name = "${var.name_prefix}-mongo" }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update -y
    apt-get install -y gnupg curl awscli
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update -y && apt-get install -y mongodb-org=4.4.22 mongodb-org-server=4.4.22 mongodb-org-shell=4.4.22
    sed -i 's/^  bindIp:.*$/  bindIp: 0.0.0.0/' /etc/mongod.conf
    echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf
    systemctl enable mongod && systemctl start mongod
    sleep 10
    mongosh --eval 'db.getSiblingDB("admin").createUser({user:"wiz",pwd:"WizPass123!",roles:[{role:"root",db:"admin"}]})'
    echo '${replace(local.backup_cron, "'", "'\\''")}' > /etc/cron.d/mongo-backup
    systemctl restart cron || service cron restart
  EOF
}
