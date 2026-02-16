## 📋 Assignment Instructions

As a DevOps engineer, you are responsible to complete the tasks by following these key areas: High Availability, Scalability, Security.

## ✅ Implementation Status

All 7 tasks completed. See [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) for detailed verification.

## 📚 Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Complete architecture documentation
- [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) - Task completion checklist
- [INFRASTRUCTURE_SETUP.md](INFRASTRUCTURE_SETUP.md) - Setup instructions
- [VALIDATION_SUMMARY.md](VALIDATION_SUMMARY.md) - Validation results

## 🎯 Tasks

**Task:**

1. Create a Dockerfile for a given application

**Expected Output:** Dockerfile

2. Build the image using the Dockerfile and push to Docker Hub

**Expected Output:** Build and push command and Docker Hub url

3. Create a Kustomize manifest to deploy the image from the previous step. The Kustomize should have flexibility to allow Developer to adjust values without having to rebuild the Kustomize frequently

**Expected Output:** Kustomize manifest file to deploy the application

4. Setup EKS cluster with the related resources to run EKS like VPC, Subnets, etc. by following EKS Best Practices using any IaC tools Terraform

**Expected Output:** IaC code

* Condition: Avoid injecting the generated AWS access keys to the application directly. 

**Expected Output:** Kustomize manifest, IaC code or anything to complete this task.

6. Use ArgoCD to deploy this application. To follow GitOps practices, we prefer to have an ArgoCD application defined declaratively in a YAML file if possible.

**Expected output:** Yaml files and instruction how to deploy the application or command line

7. Create CICD workflow using GitOps pipeline to build and deploy application

 **Expected output:** GitOps pipeline - Github workflow or diagram
