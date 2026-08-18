# Create the ALB Security Group

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for the application load balancer."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
  description     = "Allow ALB traffic to application workloads"


  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"


  security_groups = [aws_security_group.app.id]
}

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb-sg"
      Tier = "public"
    }
  )
}


# Application Security Group

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application workloads."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
  description     = "Allow application traffic to PostgreSQL"


  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"


  security_groups = [aws_security_group.db.id]
}

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-app-sg"
      Tier = "private-app"
    }
  )
}

# Database Security Group

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Security group for database workloads."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from application workloads"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress =[]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-sg"
      Tier = "private-db"
    }
  )
}