# Create the SNS topic
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alerts"
    }
  )
}

# Optional email subscription
resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ALB — 5xx alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name = "${var.name}-alb-5xx"

  alarm_description = "ALB is returning elevated HTTP 5xx responses."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  statistic = "Sum"
  period    = 300

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  threshold = 10

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}


# ALB — unhealthy targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name = "${var.name}-alb-unhealthy-targets"

  alarm_description = "ALB has unhealthy application targets."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  statistic = "Maximum"
  period    = 60

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# ALB — high latency
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name = "${var.name}-alb-latency"

  alarm_description = "ALB target response time is elevated."

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  extended_statistic = "p95"

  period = 300

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# EC2 / ASG CPU alarm
resource "aws_cloudwatch_metric_alarm" "asg_cpu" {
  alarm_name = "${var.name}-asg-high-cpu"

  alarm_description = "Application Auto Scaling Group has elevated CPU utilization."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  statistic = "Average"
  period    = 300

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 80

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# RDS CPU alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name = "${var.name}-rds-high-cpu"

  alarm_description = "RDS CPU utilization is elevated."

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  statistic = "Average"
  period    = 300

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 80

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# RDS free storage alarm
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name = "${var.name}-rds-low-storage"

  alarm_description = "RDS free storage is critically low."

  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  statistic = "Minimum"
  period    = 300

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  threshold = 5368709120

  comparison_operator = "LessThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# RDS database connections
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name = "${var.name}-rds-connections"

  alarm_description = "RDS database connections are unusually high."

  namespace   = "AWS/RDS"
  metric_name = "DatabaseConnections"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  statistic = "Average"
  period    = 300

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 80

  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = var.tags
}

# Create the CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "${var.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "ALB Request Count"

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              var.alb_arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
          region = "ap-southeast-1"

          view    = "timeSeries"
          stacked = false
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "ALB Target Response Time"

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              var.alb_arn_suffix,
              "TargetGroup",
              var.target_group_arn_suffix
            ]
          ]

          period = 300
          stat   = "Average"
          region = "ap-southeast-1"

          view = "timeSeries"
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title = "EC2 CPU Utilization"

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "AutoScalingGroupName",
              var.autoscaling_group_name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "ap-southeast-1"

          view = "timeSeries"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title = "RDS CPU Utilization"

          metrics = [
            [
              "AWS/RDS",
              "CPUUtilization",
              "DBInstanceIdentifier",
              var.db_instance_identifier
            ]
          ]

          period = 300
          stat   = "Average"
          region = "ap-southeast-1"

          view = "timeSeries"
        }
      }
    ]
  })
}