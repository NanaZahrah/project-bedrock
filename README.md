\# Project Bedrock - InnovateMart EKS Deployment



\## Overview

This repository contains the infrastructure and application code for InnovateMart's production-grade microservices deployment on AWS EKS, managed via Terraform and automated via GitHub Actions.



\## Project Architecture

\- \*\*Infrastructure:\*\* VPC with public/private subnets, EKS Cluster (v1.34.0+), RDS (MySQL/PostgreSQL), DynamoDB.

\- \*\*Observability:\*\* CloudWatch Control Plane logging \& Container Insights.

\- \*\*Serverless Extension:\*\* S3 Event-driven Lambda for asset processing.

\- \*\*Security:\*\* IAM user `bedrock-dev-view` with mapped K8s RBAC view permissions.



\## Resource Constraints

\- \*\*Region:\*\* `us-east-1`

\- \*\*Cluster Name:\*\* `project-bedrock-cluster`

\- \*\*Tagging:\*\* `Project: karatu-2025-capstone`



\## Bonus Objectives Implemented

\- \*\*5.1 Helm-Based Deployment:\*\* The `retail-store-sample-app` is deployed using a Helm chart, allowing for repeatable deployments via `helm upgrade --install`. All database configurations are injected via custom `values.yaml` to ensure managed RDS/DynamoDB usage.

\- \*\*5.2 Advanced Networking \& Ingress:\*\* The application is exposed via an ALB Ingress Controller. TLS termination is handled by AWS Certificate Manager (ACM), ensuring secure, encrypted traffic for all public-facing endpoints.



\## Deployment Guide



\### 1. CI/CD Pipeline

\- \*\*Pull Request:\*\* Triggers `terraform plan`.

\- \*\*Merge to Main:\*\* Triggers `terraform apply`.



\### 2. Accessing the Retail Store

\- \*\*URL:\*\* http://k8s-retailap-retailap-3c6aa53d7a-2129565014.us-east-1.elb.amazonaws.com



\### 3. Grading Data

\- The `grading.json` file in the root directory contains the required Terraform outputs for automated verification.



\## Setup \& Prerequisites

1\. Ensure AWS CLI is configured.

2\. Terraform remote state is configured using S3.

3\. Deploy Helm chart: `helm upgrade --install retail-store ./helm/retail-store -n retail-app`

