provider "aws" {
  region = "ap-south-1"
}

resource "aws_launch_template" "home-temp" {
   name = "home-temp"
   image_id = "ami-01a00762f46d584a1"
   instance_type = "t3.micro"
   key_name = "devops"
   user_data = base64encode (<<-EOF
   #!/bin/bash
   apt update -y
   apt install nginx -y
   echo "<h1>welcome to home page</h1> "> /var/www/html/index.html
   systemctl start nginx
   systemctl enable nginx
   EOF
 )
}

resource  "aws_launch_template" "cloth-temp" {
   name = "cloth-temp"
   image_id = "ami-01a00762f46d584a1"
   instance_type = "t3.micro"
   key_name = "devops"
   user_data = base64encode (<<-EOF
   #!/bin/bash
   apt update -y
   apt install nginx -y
   mkdir -p /var/www/html/cloth
   echo "<h1>sale sale sale</h1> "> /var/www/html/cloth/index.html
   systemctl start nginx
   systemctl enable nginx
   EOF
 )
}

resource  "aws_autoscaling_group" "home-asg" {
  name = "home-asg"
  availability_zones = ["ap-south-1a","ap-south-1b","ap-south-1c"]
  desired_capacity = 1
  max_size =1
  min_size =1
  health_check_type = "EC2"

  launch_template {
    id = aws_launch_template.home-temp.id
    version = "$Latest"
  }
}

resource  "aws_autoscaling_group" "cloth-asg" {
  name = "cloth-asg"
  availability_zones = ["ap-south-1a","ap-south-1b","ap-south-1c"]
  desired_capacity = 1
  max_size =1
  min_size =1
  health_check_type = "EC2"

  launch_template {
    id = aws_launch_template.cloth-temp.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "home-policy" {
  name = "home-policy"
  autoscaling_group_name = aws_autoscaling_group.home-asg.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = -1
  cooldown = 120
}

resource "aws_cloudwatch_metric_alarm" "home-alarm" {
  alarm_description = " this is alarm is for home policy"
  alarm_actions = [aws_autoscaling_policy.home-policy.arn]
  alarm_name = "home-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace = "AWS/EC2"
  metric_name= "CPUUtilization"
  threshold = "25"
  evaluation_periods = "5"
  period = "30"
  statistic = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.home-asg.name
  }
}

resource "aws_autoscaling_policy" "cloth-policy" {
  name = "cloth-policy"
  autoscaling_group_name = aws_autoscaling_group.cloth-asg.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = -1
  cooldown = 120
}

resource "aws_cloudwatch_metric_alarm" "cloth-alarm" {
  alarm_description = " this is alarm is for cloth policy"
  alarm_actions = [aws_autoscaling_policy.cloth-policy.arn]
  alarm_name = "cloth-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace = "AWS/EC2"
  metric_name= "CPUUtilization"
  threshold = "25"
  evaluation_periods = "5"
  period = "30"
  statistic = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.cloth-asg.name
  }
}

resource "aws_lb_target_group" "home-tg" {
  name = "home-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = "vpc-0635fdeccfe554aba"
}

resource "aws_lb_target_group" "cloth-tg" {
  name = "cloth-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = "vpc-0635fdeccfe554aba"
}

resource "aws_autoscaling_attachment" "home-attach" {
  autoscaling_group_name = aws_autoscaling_group.home-asg.id
  lb_target_group_arn = aws_lb_target_group.home-tg.arn
}

resource "aws_autoscaling_attachment" "cloth-attach" {
  autoscaling_group_name = aws_autoscaling_group.cloth-asg.id
  lb_target_group_arn = aws_lb_target_group.cloth-tg.arn
}

resource "aws_lb" "alb" {
  name = "alb"
  internal = false
  load_balancer_type = "application"
  security_groups = ["sg-038f5456173c8269a"]
  subnets = ["subnet-0b69973974f494c1e","subnet-0d243c5152b328d59","subnet-0c651437355fb89f4"]
  tags = {
    Name = "alb"
  }
}

resource "aws_lb_listener" "my-list" {
  load_balancer_arn = aws_lb.alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.home-tg.arn
  }
}

resource "aws_lb_listener_rule" "cloth-rule" {
  listener_arn = aws_lb_listener.my-list.arn
  priority = 1

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cloth-tg.arn
  }

  condition{
    path_pattern{
      values = ["/cloth/*"]
    }
  }
}
