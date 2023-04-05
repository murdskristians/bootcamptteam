ng the AWS provider
provider "aws" {
  region = "eu-central-1"
}

# Creating VPC and subnets for the application
resource "aws_vpc" "bootcamp_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.bootcamp_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.bootcamp_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}

# Creating a security group for the EC2 instance
resource "aws_security_group" "instance_sg" {
  name_prefix = "instance_sg"
  vpc_id = aws_vpc.bootcamp_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating an EC2 instance
resource "aws_instance" "wordpress_instance" {
  ami = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  key_name = "my_key_pair"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<?php phpinfo(); ?>" > /var/www/html/index.php
              EOF
}

# Creating an RDS MySQL database
resource "aws_db_instance" "wordpress_db" {
  allocated_storage = 10
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  name = "wordpress_db"
  username = "wordpress_user"
  password = "password123"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot = true

  tags = {
    Name = "wordpress_db"
  }
}

# Creating an Elastic Load Balancer
resource "aws_elb" "wordpress_elb" {
  name = "wordpress-elb"
  subnets = [aws_subnet.public_subnet.id]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }
}

# Adding the EC2 instance to the Elastic Load Balancer
resource "aws_elb_attachment" "wordpress_elb_attachment" {
  elb = aws_elb.wordpress_elb.name
  instance = aws_instance.wordpress_instance.id
  port = 80
}
