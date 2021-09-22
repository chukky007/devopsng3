terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.59.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_launch_configuration" "my-cluster" {
  image_id        = "ami-09e67e426f25ce0d7"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.elb-asg.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg-1" {
  launch_configuration = aws_launch_configuration.my-cluster.id
  #security_groups    = [aws_security_group.elb-asg.id]
  availability_zones   = data.aws_availability_zones.all.names
  min_size = 6
  max_size = 10

  load_balancers    = [aws_elb.elb-1.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_availability_zones" "all" {}
resource "aws_elb" "elb-1" {
  name               = "terraform-asg"
  availability_zones = data.aws_availability_zones.all.names

health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }


  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

resource "aws_security_group" "elb-asg" {
  name = "terraform-elb"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "clb_dns_name" {
  value       = aws_elb.elb-1.dns_name
  description = "devopsng"
}
