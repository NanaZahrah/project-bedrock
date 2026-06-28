# Project Bedrock - InnovateMart EKS Deployment

## Architecture
- VPC: project-bedrock-vpc (us-east-1)
- EKS Cluster: project-bedrock-cluster (v1.34)
- RDS MySQL: bedrock-mysql
- RDS PostgreSQL: bedrock-postgres
- DynamoDB: bedrock-checkout
- S3: bedrock-assets-alt-soe-025-3603
- Lambda: bedrock-asset-processor

## How to trigger the pipeline
- Open a Pull Request ? triggers `terraform plan` (output posted as PR comment)
- Merge to main ? triggers `terraform apply`

## Deploy the app
```bash
kubectl apply -f k8s/namespace/namespace.yaml
kubectl apply -f k8s/deployments/retail-store.yaml
kubectl apply -f k8s/deployments/rabbitmq-service.yaml
kubectl apply -f k8s/ingress/ingress.yaml
```

## Tags
All resources tagged with: Project: karatu-2025-capstone
