# Project Bedrock - InnovateMart EKS Deployment
Student ID: ALT/SOE/025/3603

## Architecture
- VPC: project-bedrock-vpc (us-east-1)
- EKS Cluster: project-bedrock-cluster (v1.34)
- RDS MySQL: bedrock-mysql
- RDS PostgreSQL: bedrock-postgres
- DynamoDB: bedrock-checkout
- S3: bedrock-assets-alt-soe-025-3603
- Lambda: bedrock-asset-processor

## Live App URL
http://k8s-retailap-retailst-17d19cf248-1663934035.us-east-1.elb.amazonaws.com

## How to trigger the pipeline
- Open a Pull Request to main ? triggers terraform plan (posted as PR comment)
- Merge to main ? triggers terraform apply

## Deploy the app
```bash
kubectl apply -f k8s/namespace/namespace.yaml
kubectl apply -f k8s/deployments/retail-store.yaml
kubectl apply -f k8s/deployments/rabbitmq-service.yaml
kubectl apply -f k8s/deployments/orders-fix.yaml
kubectl apply -f k8s/deployments/catalog-fix.yaml
kubectl apply -f k8s/ingress/ingress.yaml
```

## Developer Access (bedrock-dev-view)
- Console URL: https://856802649206.signin.aws.amazon.com/console
- ReadOnly AWS access + Kubernetes view role in retail-app namespace

## Resource Tagging
All resources tagged with: Project: karatu-2025-capstone

## grading.json
Committed to root of repository. Generated with:
```bash
terraform output -json > grading.json
```
