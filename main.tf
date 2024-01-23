resource "aws_vpc" "poc_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "poc_vpc"
  }
}

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

## Adding subnet into 2 AZ i.e. ap-south-1a & 1b as per mentioned in variable "azs" block

resource "aws_subnet" "poc_public_subnets" {
    count      = length(var.public_subnet_cidrs)
    vpc_id     = aws_vpc.poc_vpc.id
    cidr_block = element(var.public_subnet_cidrs, count.index)
    availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}

## Creating route table with IGW 
resource "aws_route_table" "route_poc" {
    vpc_id = aws_vpc.poc_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw_poc.id
    }
  
}

## Attaching route table with IGW to existing public subnets 
resource "aws_route_table_association" "public_subnet_rt" {
    count          = length(var.public_subnet_cidrs)
 #   subnet_id      = aws_subnet.poc_public_subnets.id
    subnet_id      = element(aws_subnet.poc_public_subnets[*].id, count.index)
    route_table_id = aws_route_table.route_poc.id
  
}

## Creating IGW & attaching it to newly created vpc 
resource "aws_internet_gateway_attachment" "igw_poc" {
  internet_gateway_id = aws_internet_gateway.igw_poc.id
  vpc_id              = aws_vpc.poc_vpc.id
}

resource "aws_internet_gateway" "igw_poc" {

    tags = {
        Name  = "igw_poc"
    }
}

###Creating web server 

resource "aws_security_group" "webserver_sg" {
  vpc_id      = aws_vpc.poc_vpc.id

  tags = {
    Name = "webserver_sg"
  }
ingress {
   description = "HTTP ingress"
   from_port   = 80
   to_port     = 8080
   protocol    = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
   description = "ssh ingress"
   from_port   = 22
   to_port     = 22
   protocol    = "tcp"
   cidr_blocks = ["122.161.51.208/32"]
 }

egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }

}

## Creation of LT which is required for ASG
resource "aws_launch_template" "webserver_lt" {
  name_prefix   = "webserver_lt"
#  image_id      = aws_ami_from_instance.webserver-ami.id
  image_id = "ami-03f4878755434977f"
  instance_type = "t2.micro"
  key_name = "aws-test"

## Changing webserver port from 80 to 8080 via user_data.sh
  user_data = filebase64("/Users/ankur.vaish/Desktop/TF/user_data.sh")
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.webserver_sg.id]
  }
}

## Creation of ASG and attaching newly created server to existing TG's
resource "aws_autoscaling_group" "webserver_asg" {
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
 # vpc_zone_identifier = ["${aws_subnet.poc_public_subnets[count.index].id}"]
  vpc_zone_identifier = aws_subnet.poc_public_subnets[*].id
  target_group_arns = ["${aws_lb_target_group.webserver_tg.arn}"]

## Pointing LT to always point to latest version
  launch_template {
    id      = aws_launch_template.webserver_lt.id
    version = "$Latest"
  }
}

## Creating target group for alb 
resource "aws_lb_target_group" "webserver_tg" {
  name        = "webserver-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.poc_vpc.id
  
}

##Creating application load balancer
resource "aws_lb" "webserver_lb" {
  name               = "webserver-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webserver_sg.id]
  subnets            = aws_subnet.poc_public_subnets[*].id

  enable_deletion_protection = false


  tags = {
    Environment = "poc"
    Name        = "webserver-alb"
  }
}

## Adding listener rule with alb 
resource "aws_lb_listener" "webserver_listener" {
  load_balancer_arn = aws_lb.webserver_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver_tg.arn
  }
}


## IAM user creation 
resource "aws_iam_user" "ec2-restart" {
  name = "ec2-restart"
}

resource "aws_iam_access_key" "ec2-restart" {
  user = aws_iam_user.ec2-restart.name
}

data "aws_iam_policy_document" "developer" {
  statement {
    effect    = "Allow"
    actions   = [
        "ec2:StartInstances",
        "ec2:StopInstances",
        ]

    resources = ["arn:aws:ec2:*:*:instance/*"] 
  }
}

## Creating policy for ec2 start/stop actions
resource "aws_iam_user_policy" "developer" {
  name   = "developer-test"
  user   = aws_iam_user.ec2-restart.name
  policy = data.aws_iam_policy_document.developer.json
}
