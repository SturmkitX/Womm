resource "aws_security_group" "womm-demo-sg" {
  name    = "womm-demo-sg-01"
  vpc_id  = aws_vpc.womm-vpc-01.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Ping"
    protocol         = "icmp"
    from_port        = -1
    to_port          = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface" "womm-demo-01-nic" {
  subnet_id = aws_subnet.womm-subnet-01.id
  security_groups = [aws_security_group.womm-demo-sg.id]
}

resource "aws_instance" "kube-worker-01" {
  ami           = "ami-064087b8d355e9051"
  instance_type = "t3.micro"

  network_interface {
    network_interface_id  = aws_network_interface.womm-demo-01-nic.id
    device_index          = 0
  }

  root_block_device {
    delete_on_termination = true
    volume_type = "gp2"
    volume_size = 40
  }

#   associate_public_ip_address = true

  key_name      = aws_key_pair.demo-keypair-01.key_name
  tags = {
    Name = "womm-demo-01"
    Role = "VM used for manual testing purposes"
  }

  # depends_on = [ aws_internet_gateway.kube-vpc-gw-01 ]
}

resource "aws_key_pair" "demo-keypair-01" {
  key_name    = "womm-ssh-demo"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKAzdc04BNfDEDyAnUO8rQuUpO3jHL2IzF4jeKeqFAVhS39OuuYfYCz1EKCFD7ieSVgu0zCoHV9co1zRKiaMKSX8+G90Apl32D5a4hhAZdlPzyecnTEBINHTJwUX9vupgPwDMhOGrfQi82QmjvXja+RXQOoZSWw1pP8tIjA6N6psrGN3cyh/BnY1iTc5AgHgTxlehMELiRHa6I6BllWw1R0kPcjBVoIrkg3oykMdnaVfryL1RvPn/UFUuYz38XkomTHJtGy3Q1S0v5KO1Y+dtQ9/mgqzh7/GbGuiulMHJuxA19Q76wbnzSvfnLGkpr5scmXKfSNWCu/pdsutexE8Uy6In8huUgDZCnwOxo1w6ILcbAJCU+Q4KxpgtUncB2hvPkMDDgBpDLp6c0YjqCu9kmtgJIhXGaN5ih72yiIsS1MiN1wfV6hQXuN6ftTiUck86mQpWaSb2IEd0ZyaWwfJLi3X4xA91jhemsJskPqhrR3bYjsl822fZMvXNRQX+ipYs= bogdan rogoz@DESKTOP-29ET554"

  tags = {
    Name  = "womm-ssh-demo"
  }
}

resource "aws_eip" "bar" {
#   domain = "vpc"

#   instance                  = aws_instance.kube-worker-01.id
#   associate_with_private_ip = "10.0.0.12"
  network_interface = aws_network_interface.womm-demo-01-nic.id
  depends_on                = [aws_internet_gateway.gw]
}
