# Day 1: Introduction to Infrastructure as Code: Exploring Terraform

🧪 Hands-On Lab: Explore Terraform Basics
Prerequisites

An AWS account (free tier)

A computer with internet access

Lab Steps

### Step 1: Create Your AWS Account

Go to https://aws.amazon.com

Click “Create an AWS Account”

Follow the signup process (requires credit card but we’ll use free tier)

Verify your email

### Step 2: Understand the AWS Free Tier

AWS provides 750 hours/month of t2.micro instances (free for 12 months)

We’ll stay within free tier limits throughout this series

Always remember to destroy resources after practice!

### Step 3: Familiarize with AWS Console

Log into AWS Console: https://console.aws.amazon.com

Navigate to EC2 Dashboard

Browse around - notice how many clicks it takes to launch an instance

Don’t create anything yet - just explore

### Step 4: Understand the Manual Process Count the steps to manually create an EC2 instance:

Choose AMI (Amazon Machine Image)

Choose Instance Type

Configure Instance Details

Add Storage

Add Tags

Configure Security Group

Review and Launch

Create/Select Key Pair

That’s 8+ steps with dozens of options! Tomorrow, we’ll do this with just a few lines of code.



📚 Summary

Today I learned:

✅ What Infrastructure as Code is and why it matters

✅ What Terraform is and how it works

✅ The three-step Terraform workflow (Write, Plan, Apply)

✅ Key advantages of using Terraform over manual processes

✅ Basic Terraform concepts (providers, resources, state)


This lab was built using [StackOps - Diary](https://stackopsdiary.site/day-1-introduction-to-infrastructure-as-code-exploring-terraform).