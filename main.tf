resource "aws_instance" "example" {
  ami                         = "ami-053b0d53c279acc90"
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.name.key_name
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  depends_on                  = [aws_security_group.ec2_sg, aws_key_pair.name]
  subnet_id                   = aws_subnet.public_subnet.id
  user_data_replace_on_change = true
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
  tags = {
    Name = "custom-vpc-ec2"
  }
  connection {
    user        = "ubuntu"
    type        = "ssh"
    host        = self.public_ip
    private_key = file("terra-key-ec2")
  }
  provisioner "file" {
    source      = "app.py"
    destination = "/home/ubuntu/app.py"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from the remote instance'",
      "sudo apt update -y",
      "sudo apt-get install -y python3-pip",
      "sudo pip3 install flask --break-system-packages",
      "nohup sudo python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &",
      "sleep 2",
    ]
  }

}

resource "aws_key_pair" "name" {
  key_name   = "ec2"
  public_key = file("terra-key-ec2.pub")
}
# 1. Create Custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "custom-vpc"
  }
}


# 2. Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "custom-igw"
  }
}


# 3. Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Ensures EC2 gets a public IP

  tags = {
    Name = "custom-public-subnet"
  }
}

# 4. Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "custom-public-rt"
  }
}

# 5. Associate Route Table with Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Create Security Group for SSH
resource "aws_security_group" "ec2_sg" {
  name        = "allow-ssh"
  description = "Allow inbound SSH traffic"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP for production
  }
  ingress {
    description = "Web Site Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}
