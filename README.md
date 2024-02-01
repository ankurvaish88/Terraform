**Created this Terraform code for deploying entire webserver infra accepting traffic from port 80 from world and redirecting to 8080**

1. This TF scripts creates VPC and subnets attached to IGW for internet access
    - Subnets (ap-south-1a and ap-south-1b)
2. Creating ASG to launch webservers (apache2) within same vpc
3. Creation of launch template with user-date to change default port of apache2 from 80 -> 8080 via script (user_data.sh)
4. Creating ALB & TG's
5. Attaching webservers to TG's with listener rules.
6. Creating an IAM user "ec2-restart" for access to restart ec2 machinnes only.
