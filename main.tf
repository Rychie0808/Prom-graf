provider "aws" {
  profile = "default"
  region  = "us-east-2"

}

# RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

//Creating private key
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "prom.pem"
  file_permission = "600"
}

//create my public key on aws
resource "aws_key_pair" "keypair" {
  key_name   = "prom-key"
  public_key = tls_private_key.keypair.public_key_openssh
}

//security group for prometheus and grafana 
resource "aws_security_group" "prom_graf_sg" {
  name        = "prom-graf-sg"
  description = "Allow Inbound Traffic"

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "prometheus_ui"
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "node_exporter_port"
    protocol    = "tcp"
    from_port   = 9100
    to_port     = 9100
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "grafana_ui"
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "prom_graf_sg"
  }
}


//security group for maven 
resource "aws_security_group" "target_server_sg" {
  name        = "target_server_sg"
  description = "Allow Inbound Traffic"

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "node_exporter_port"
    protocol    = "tcp"
    from_port   = 9100
    to_port     = 9100
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "target_server_sg"
  }
}


//create ec2 for Prometheus and  Grafana
resource "aws_instance" "prom_graf" {
  ami                         = "ami-085f9c64a9b75eed5"
  instance_type               = "t2.medium"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.prom_graf_sg.id]
  user_data = templatefile("./install.sh", {
    nginx_webserver_ip = aws_instance.ec2.public_ip
  })
  depends_on = [aws_instance.ec2]
  tags = {
    name = "prom_graf"
  }
}

//create ec2 for Prometheus and  Grafana
resource "aws_instance" "ec2" {
  ami                         = "ami-085f9c64a9b75eed5"
  instance_type               = "t2.medium"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.target_server_sg.id]
  user_data                   = file("./install2.sh")
  tags = {
    name = "ec2-instance"
  }
}

output "prom-graf-ip" {
  value = aws_instance.prom_graf.public_ip
}

output "ec2-ip" {
  value = aws_instance.ec2.public_ip
}