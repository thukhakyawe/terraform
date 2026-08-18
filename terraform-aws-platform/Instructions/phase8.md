Phase 8 — Enterprise Observability & Monitoring

Our goal is to monitor the three major runtime layers:

                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │      ALB      │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   EC2 / ASG   │
                    │  App Servers  │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   PostgreSQL  │
                    │      RDS      │
                    └───────────────┘


       ┌──────────────────────────────────────────┐
       │            CloudWatch                    │
       │                                          │
       │ Metrics → Alarms → SNS → Notification   │
       │                                          │
       │ Dashboard → Operational visibility       │
       └──────────────────────────────────────────┘

We're going to focus on actionable signals, not dozens of meaningless alarms.

8.1 What we're going to build

We'll create a new Terraform module:

modules/
└── monitoring/
    ├── versions.tf
    ├── variables.tf
    ├── main.tf
    └── outputs.tf

The module will manage:

ALB monitoring
HTTP 5xx errors
unhealthy targets
high response time
EC2 / ASG monitoring
CPU utilization
unhealthy instances through the ASG
RDS monitoring
CPU utilization
free storage
database connections
Notifications
SNS topic
CloudWatch alarm → SNS
Dashboard

A single CloudWatch dashboard showing the platform's important operational signals.

8.2 Why this matters for your SRE resume

This is much stronger than saying:

"Configured CloudWatch."

We're building something you can eventually describe as:

Implemented infrastructure-as-code observability with CloudWatch dashboards and actionable alarms across ALB, EC2 Auto Scaling, and RDS, with SNS-based incident notification.

That fits your target SRE/DevOps roles much better.

8.3 Create the monitoring module

From your repository root:

mkdir -p modules/monitoring

Check:

tree modules/monitoring

Initially it will be empty.

8.4 Create versions.tf

Create:

modules/monitoring/versions.tf

Use:

terraform {
  required_version = ">= 1.10.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
8.5 Create monitoring variables

Create:

modules/monitoring/variables.tf

Use:

variable "name" {
  description = "Name prefix for monitoring resources."
  type        = string
}


variable "environment" {
  description = "Deployment environment."
  type        = string
}


variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metrics."
  type        = string
}


variable "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch metrics."
  type        = string
}


variable "autoscaling_group_name" {
  description = "Auto Scaling Group name."
  type        = string
}


variable "db_instance_identifier" {
  description = "RDS instance identifier."
  type        = string
}


variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications."
  type        = string
  default     = ""
}


variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
Important

We're using:

alb_arn_suffix
target_group_arn_suffix

rather than the full ARN because that's what CloudWatch's AWS/ApplicationELB dimensions expect.

8.6 Create the SNS topic

Open:

modules/monitoring/main.tf

Add:

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alerts"
    }
  )
}

This becomes our notification channel.

Architecture:

CloudWatch Alarm
       │
       ▼
   SNS Topic
       │
       ▼
 Email / Incident System
8.7 Optional email subscription

Add:

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0


  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

This is deliberately optional.

If you don't provide an email address:

alarm_email = ""

Terraform won't create the subscription.

If you do provide one, AWS will send a confirmation email.

Do not put your personal email into the GitHub repository.

8.8 ALB — 5xx alarm

Add:

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
Why 5xx?

A 5xx response generally indicates a server-side failure.

We're not alerting on one isolated error.

We're looking for:

10+ errors
for
2 consecutive 5-minute periods

That is much more operationally meaningful.

8.9 ALB — unhealthy targets

Add:

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

This is a very useful operational alarm.

It tells us:

At least one application target has become unhealthy.

8.10 ALB — high latency

Now add:

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

This is an important SRE concept.

We're monitoring latency, not just whether the system is technically "up."

8.11 EC2 / ASG CPU alarm

Add:

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

This doesn't mean:

CPU > 80% = incident.

It means:

CPU remains elevated long enough to potentially indicate resource pressure.

Later we can improve this with Auto Scaling policies.

8.12 RDS CPU alarm

Add:

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
8.13 RDS free storage alarm

This one is particularly important.

Add:

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

The threshold is:

5 GiB

because CloudWatch reports FreeStorageSpace in bytes.

8.14 RDS database connections

Add:

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

This is another useful operational signal because connection exhaustion can become an application availability problem.

8.15 Create the CloudWatch dashboard

Now we'll create the visual operational dashboard.

Add to main.tf:

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


          view   = "timeSeries"
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
8.16 Why we're creating a dashboard

This is the operational view an SRE could use during an incident:

┌────────────────────────────────────────────────────┐
│              PLATFORM DASHBOARD                    │
├─────────────────────────┬──────────────────────────┤
│ ALB Request Count       │ Target Response Time     │
│                         │                          │
│       /\                │       /\                 │
│      /  \               │   ___/  \___             │
├─────────────────────────┼──────────────────────────┤
│ EC2 CPU                 │ RDS CPU                  │
│                         │                          │
│       /\                │       /\                 │
│      /  \               │      /  \                │
└─────────────────────────┴──────────────────────────┘

Later we'll add more sophisticated signals.

8.17 Outputs

Create:

modules/monitoring/outputs.tf

Use:

output "sns_topic_arn" {
  description = "SNS topic ARN for platform alerts."
  value       = aws_sns_topic.alerts.arn
}


output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.platform.dashboard_name
}
8.18 Connect monitoring to dev

Now open:

environments/dev/main.tf

Add:

module "monitoring" {
  source = "../../modules/monitoring"


  name        = "${var.project_name}-${var.environment}"
  environment = var.environment


  alb_arn_suffix = module.alb.alb_arn_suffix


  target_group_arn_suffix = module.alb.target_group_arn_suffix


  autoscaling_group_name = module.compute.autoscaling_group_name


  db_instance_identifier = module.database.db_instance_id


  alarm_email = ""


  tags = {
    Environment = var.environment
  }
}
Important

The above assumes your ALB module exports:

alb_arn_suffix
target_group_arn_suffix

and your compute module exports:

autoscaling_group_name

Your database module already exports:

db_instance_id

If your ALB module currently doesn't expose the two suffixes, don't invent them in dev/main.tf.

We'll add those outputs.

8.19 Add ALB outputs if needed

Open:

modules/alb/outputs.tf

Make sure you have:

output "alb_arn_suffix" {
  description = "ALB ARN suffix used for CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}


output "target_group_arn_suffix" {
  description = "Target group ARN suffix used for CloudWatch dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}

If those outputs already exist, don't duplicate them.

8.20 Add development outputs

Open:

environments/dev/outputs.tf

Add:

output "monitoring_sns_topic_arn" {
  description = "SNS topic ARN for platform alerts."
  value       = module.monitoring.sns_topic_arn
}


output "monitoring_dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.monitoring.dashboard_name
}
8.21 Format

From repository root:

terraform fmt -recursive

Then:

cd environments/dev
8.22 Initialize

Because we're using only the existing AWS provider:

terraform init

You should see successful initialization.

8.23 Validate

Run:

terraform validate

Expected:

Success! The configuration is valid.
8.24 Plan

Now:

terraform plan

Do not apply.

We previously had:

39 to add

Phase 8 should add approximately:

1 SNS topic
1 SNS subscription only if email is configured
7 CloudWatch alarms
1 CloudWatch dashboard

So with alarm_email = "", expect approximately:

Plan: 48 to add, 0 to change, 0 to destroy.

The exact number may differ depending on your current module implementation.

8.25 What I want you to check

Your plan should contain resources similar to:

module.monitoring.aws_sns_topic.alerts


module.monitoring.aws_cloudwatch_metric_alarm.alb_5xx


module.monitoring.aws_cloudwatch_metric_alarm.alb_unhealthy_targets


module.monitoring.aws_cloudwatch_metric_alarm.alb_latency


module.monitoring.aws_cloudwatch_metric_alarm.asg_cpu


module.monitoring.aws_cloudwatch_metric_alarm.rds_cpu


module.monitoring.aws_cloudwatch_metric_alarm.rds_free_storage


module.monitoring.aws_cloudwatch_metric_alarm.rds_connections


module.monitoring.aws_cloudwatch_dashboard.platform

And most importantly:

Plan: XX to add, 0 to change, 0 to destroy.
Don't worry about email yet

For now:

alarm_email = ""

is intentional.

Once the infrastructure is actually deployed, we can configure an SNS email subscription and test an alarm.

That avoids creating unnecessary AWS resources while we're still building the project.