# ec2.tf: Three EC2 instances (beta, gamma, prod) with SSM-managed profile, Docker pre-installed via user_data, and an elastic IP each so GitHub Actions/health checks can reach them.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}


resource "aws_instance" "app" {
  for_each                    = toset(var.environment_names)
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf update -y
    dnf install -y docker git jq
    systemctl enable --now docker
    usermod -aG docker ec2-user
    # Docker Compose v2 plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    # Deploy dir
    mkdir -p /opt/app
    chown ec2-user:ec2-user /opt/app
    # Marker for env
    echo "${each.key}" > /opt/app/ENV
  EOF

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = each.key
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "app" {
  for_each = toset(var.environment_names)
  instance = aws_instance.app[each.key].id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-${each.key}-eip" }
}
