variable project {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "fargate" {
  name        = "${var.project}_fargate"
  description = "Allow all traffic from within VPC"
  vpc_id      = data.aws_vpc.default.id 

  ingress {
    description      = "All from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["${data.aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project}_rds"
  subnet_ids = [ for subnet in data.aws_subnets.private_subnets.ids : subnet ]
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

  # TODO: We definitely need to add access to here from lambda functions
  ingress {
    description      = "Allow access from project security group(s)"
    from_port        = 3306
    to_port          = 3306
    protocol         = "TCP"
    security_groups = ["${aws_security_group.fargate_spot.id}"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "fargate_security_group" {
  value = aws_security_group.fargate.id
}

output "rds_security_group" {
  value = aws_security_group.rds_security.id
}

output "rds_subnet_group" {
  value = aws_db_subnet_group.rds.name
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "public_subnets" {
  value   = [ for subnet in data.aws_subnets.public_subnets.ids : subnet ]
}
