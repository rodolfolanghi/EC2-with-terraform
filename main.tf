provider "aws" {
  region     = var.your-region
  access_key = var.your-access_key
  secret_key = var.your-secret_key
}



# 1 Creat vpc

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# 2 Creat Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  
}

# 3 creat custom route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4 creat a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "prod-subnet"
  }
}

# 5 associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6 creat security group to allow port 22, 80, 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"          # Permitir somente o tráfico web
  description = "Allow Web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress  {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Todos acessam
  }
 
   ingress  {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

   ingress  {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }

}

# 7 creat a network interface with an ip in the subnet that was creat in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8 assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 9 creat ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
    ami = "ami-09040d770ffe2224f"
    instance_type = "t2.micro"
    availability_zone = "us-east-2b" #Tem que ser a mesma zona de disponibilidade quando criamos a subnet. A mesma zona da nossa instância criada na aws
    key_name = "main-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #"/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo you very first web server > /var/www/html/index.html'
                EOF
    tags = {
        Name = "web-server-2"
    }
}