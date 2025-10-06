variable project {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "project_interop" {
  name = "${var.project}-interop"
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project}_rds"
  subnet_ids = [ for subnet in data.aws_subnets.default_subnets.ids : subnet ]
}


resource "aws_security_group" "rds_security" {
  name        = "${var.project}_rds"
  description = "Allow swl.si.umich.edu to access RDS"
  vpc_id      = data.aws_vpc.default.id 

  ingress {
    description      = "MySQL from SWL"
    from_port        = 3306
    to_port          = 3306
    protocol         = "TCP"
    cidr_blocks      = ["141.211.192.69/32"]
  }

  ingress {
    description      = "Allow access from project security group(s)"
    from_port        = 3306
    to_port          = 3306
    protocol         = "TCP"
    security_groups = ["${data.aws_security_group.project-interop.id}"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
