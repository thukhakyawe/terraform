# ============================================================
# ALB Security Group
# ============================================================

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for the application load balancer."
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb-sg"
      Tier = "public"
    }
  )
}


# ============================================================
# Application Security Group
# ============================================================

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application workloads."
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-app-sg"
      Tier = "private-app"
    }
  )
}


# ============================================================
# Database Security Group
# ============================================================

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Security group for database workloads."
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-sg"
      Tier = "private-db"
    }
  )
}


# ============================================================
# ALB Ingress Rules
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "HTTP from the internet"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  cidr_ipv4 = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "HTTPS from the internet"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  cidr_ipv4 = "0.0.0.0/0"
}


# ============================================================
# ALB Egress → Application
# ============================================================

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow ALB traffic to application workloads"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}


# ============================================================
# Application Ingress ← ALB
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id

  description                  = "Application traffic from ALB"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}


# ============================================================
# Application Egress → Database
# ============================================================

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id

  description                  = "Allow application traffic to PostgreSQL"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}


# ============================================================
# Database Ingress ← Application
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id

  description                  = "PostgreSQL from application workloads"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}