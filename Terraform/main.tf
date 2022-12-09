provider "aws" {
    region = "us-east-2"
}

resource "aws_launch_configuration" "whisk" {
    image_id        = "ami-0fb653ca2d3203ac1"
    instance_type   = "t2.micro"

    security_groups = [aws_security_group.whisk_security.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Roll-out my-whisk" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_security_group" "whisk_security" {
    name = "whish-security-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_autoscaling_group" "whisk_autoscaling" {
    launch_configuration = aws_launch_configuration.whisk.name
    vpc_zone_identifier = data.aws_subnets.default.ids

    target_group_arns = [aws_lb_target_group.whisk_lb_target_group.arn]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "whisk-instance"
        propagate_at_launch = true
    }
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_lb" "whisk_lb" {
    name = "whisk-lb"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.whisk_lb_security.id]
}

resource "aws_lb_listener" "whisk_lb_listener" {
    load_balancer_arn = aws_lb.whisk_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: content not found"
        status_code = 404
      }
    }
}

resource "aws_security_group" "whisk_lb_security" {
    name = "whisk-lb-security"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "whisk_lb_target_group" {
    name = "whisk-lb-target-group"
    protocol = "HTTP"
    port = var.server_port
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener_rule" "whisk_lb_listener_rule" {
    listener_arn = aws_lb_listener.whisk_lb_listener.arn
    priority = 100

    condition {
        path_pattern {
            values =["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.whisk_lb_target_group.arn
    }
}

variable "server_port" {
    description = "ingress port number for incoming & outgoing traffic"
    type = number
    default = 8080
}

# output "public_ip" {
#     description = "Public IP address of EC2 Instance"
#     value = aws_launch_configuration.whisk.public_ip
# }

output "whisk_lb_dns_name" {
    value = aws_lb.whisk_lb.dns_name
    description = "The domain name of the load balancer"
}