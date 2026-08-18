# Find an AMI dynamically
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [
    var.security_group_id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash

    dnf update -y

    dnf install -y python3

    mkdir -p /opt/app

    cat > /opt/app/server.py <<'PYTHON'
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"healthy")
            else:
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"terraform-aws-platform")

        def log_message(self, format, *args):
            return

    server = HTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
    PYTHON

    cat > /etc/systemd/system/platform-app.service <<'SERVICE'
    [Unit]
    Description=Terraform AWS Platform Application
    After=network.target

    [Service]
    ExecStart=/usr/bin/python3 /opt/app/server.py
    Restart=always
    User=root

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable platform-app
    systemctl start platform-app
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-app"
        Tier = "private-app"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-app-volume"
      }
    )
  }
}

# Create the Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name = "${var.name}-app-asg"

  min_size         = var.min_size
  desired_capacity = var.desired_size
  max_size         = var.max_size

  vpc_zone_identifier = var.private_app_subnet_ids

  target_group_arns = [
    var.target_group_arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = lookup(var.tags, "Environment", "unknown")
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "private-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}