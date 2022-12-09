provider "aws" {
    region = "us-east-2"
}

resource "aws_instance" "whisk" {
    ami           = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"

    vpc_security_group_ids = [aws_security_group.whisk_security.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Roll-out my-whisk" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF

    user_data_replace_on_change = true

    tags = {
        Name = "whisk-ec2-instance"
    }
}

resource "aws_security_group" "whisk_security" {
    name = "whish security instance"

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

