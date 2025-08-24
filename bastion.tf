resource "aws_instance" "bastion" {
  ami                         = "ami-03aa99ddf5498ceb9"
  instance_type               = "t3a.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name = "temp"
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}
