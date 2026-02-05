resource "aws_launch_template" "app_lt" {
  name_prefix   = "web-app-lt-"
  image_id      = "ami-02f2230845208fdc0"
  instance_type = "t3.micro"
  key_name      = "nn"

  network_interfaces {
    security_groups = [aws_security_group.app_sg.id]
    associate_public_ip_address = false

  }

  
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "launch template for app sg"
    }
  }
}








