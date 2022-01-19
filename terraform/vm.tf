resource "aws_vpc" "gw_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "tf-example"
  }
}

resource "aws_subnet" "gw_subnet" {
  vpc_id            =  aws_vpc.gw_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "tf-example"
  }
}

resource "aws_network_interface" "gw_ni" {
  subnet_id   = aws_subnet.gw_subnet.id
  private_ips = ["172.16.10.100"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_sonar"
  description = "Allow sonar inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_sonar"
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0f9124f7452cdb2a6"
  instance_type = "t2.micro"
  tags = {
    Name = "sonar-cloud"
  }
  network_interface {
    network_interface_id = aws_network_interface.gw_ni.id
    device_index         = 0
  }
}