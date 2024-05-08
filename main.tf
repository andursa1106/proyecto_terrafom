
locals {
    project = jsondecode(file("./config/project.json"))
    environment = jsondecode(file("./config/environment.json"))
}

provider "aws" {
    region     = "us-west-2"
    default_tags {
        tags = {
            PROYECTO = "${local.project.tag-recursos}"
        }
    }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_default_tags" "current" {}


## CLUSTER #############################################################################################################################

resource "aws_ecr_repository" "ecr_repositories" {
    count = length(local.project.microservicios)
    name = "${local.project.nombre}/${local.project.microservicios[count.index].nombre}-repository"

}

resource "aws_ecs_cluster" "cluster" {
    name = "cluster-${local.project.nombre}-${local.environment.ambiente}"
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "awslogs-${local.project.nombre}"
}

resource "aws_ecs_task_definition" "tasks_definition" {
    family = "${local.project.nombre}-${local.project.microservicios[count.index].nombre}-task"
    count = length(local.project.microservicios)
    network_mode = "bridge"
    container_definitions = jsonencode([{
        "name": "${local.project.nombre}-${local.project.microservicios[count.index].nombre}-task"
        "image": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.project.nombre}/${local.project.microservicios[count.index].nombre}-repository:latest",
        "cpu": 128,
        "memory": 128,
        "portMappings": [{
            "containerPort": 80,
            "hostPort" : 0,
            "protocol": "tcp"
        }],
        "logConfiguration" : {
            "logDriver" : "awslogs" ,
            "options" : {
                "awslogs-group": aws_cloudwatch_log_group.log_group.name,
                "awslogs-region": "${data.aws_region.current.name}",
                "awslogs-stream-prefix": "${local.project.nombre}-${local.project.microservicios[count.index].nombre}-service"
            }
        }
    }])
}

resource "aws_ecs_service" "services" {
    count = length(local.project.microservicios)
    name = "${local.project.nombre}-${local.project.microservicios[count.index].nombre}-service"
    cluster = aws_ecs_cluster.cluster.id
    task_definition = aws_ecs_task_definition.tasks_definition[count.index].arn
    desired_count = 1
    depends_on = [ aws_cloudwatch_log_group.log_group ]
}

## BALANCEADOR Y TARGET GROUP ########################################################################################################

resource "aws_security_group" "alb_security_group" {
    name = "${local.project.nombre}-alb-security-group"
    vpc_id = local.environment.main_vpc  

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "target_group" {
  count = length(local.project.microservicios)
  name = "TG-${upper(local.project.nombre)}-${upper(local.project.microservicios[count.index].nombre)}-SERVICE"
  port = 80
  protocol = "HTTP"
  vpc_id = local.environment.main_vpc
}

resource "aws_lb" "application_load_balancer" {
  name = "lb${local.environment.ambiente-corto}-${local.project.nombre}-microservicios"
  load_balancer_type = "application"
  subnets = [local.environment.main_subnet, local.environment.secondary_subnet]
  security_groups = [ aws_security_group.alb_security_group.id  ]
}

resource "aws_lb_listener" "alb_listener" {
    load_balancer_arn = aws_lb.application_load_balancer.arn
    port = 80
    protocol = "HTTP"

    default_action {
        type = "redirect"
        redirect {
            port = "443"
            protocol = "HTTPS"
            status_code = "HTTP_301"
        }
    }
}

resource "aws_lb_listener_rule" "alb_listener_rule" {
    count = length(local.project.microservicios)
    listener_arn = aws_lb_listener.alb_listener.arn
    
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.target_group[count.index].arn 
    }

    condition {
      path_pattern{
        values = ["${local.project.microservicios[count.index].context-path}/*"]
      }
    }
}

## AUTOSCALING #######################################################################################################################

resource "aws_iam_policy" "instance_policy" {
  name        = "${local.project.nombre}-instance-policy"
  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Action": [
      "ecs:DiscoverPollEndpoint",
      "ecs:CreateCluster",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetAuthorizationToken",
      "ecs:RegisterContainerInstance",
      "ecs:SubmitTaskStateChange",
      "ecr:UploadLayerPart",
      "logs:PutLogEvents",
      "ecr:Submit*",
      "ecs:Poll",
      "logs:CreateLogStream",
      "ecs:StartTelemetrySession",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecs:DeregisterContainerInstance",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:RegisterTaskDefinition"
    ],
    "Resource": "*"
  }
]
}
EOF
}

resource "aws_iam_role" "instance_role" {
  name = "${local.project.nombre}-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
    role = aws_iam_role.instance_role.name
    policy_arn = aws_iam_policy.instance_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
    name = "${local.project.nombre}-instance-profile"
    role = aws_iam_role.instance_role.name
}

##################################################################################

resource "aws_security_group" "ec2_security_group" {
    name = "${local.project.nombre}-ec2-security-group"
    vpc_id = local.environment.main_vpc

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        security_groups = [ aws_security_group.alb_security_group.id ]
    }  

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_template" "launch_template" {
    name_prefix = "${local.project.nombre}-launch-template"
    image_id = local.environment.instance-ami-id
    instance_type = local.environment.instance-type-id

    iam_instance_profile {
        name = aws_iam_instance_profile.instance_profile.name
    }  

    vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
    user_data = base64encode(templatefile("./config/user_data.txt", { nombre_cluster = local.project.nombre , ambiente_cluster = local.environment.ambiente}))

}

resource "aws_autoscaling_group" "autoscaling_group" {
    name = "${local.project.nombre}-autoscaling-group"
    min_size = 1
    max_size = 1
    desired_capacity = 1

    launch_template {
        id = aws_launch_template.launch_template.id
        version = "$Latest"    
    }

    vpc_zone_identifier  = [local.environment.main_subnet]

    dynamic "tag" {
        for_each = data.aws_default_tags.current.tags
        content {
            key = tag.key
            value = tag.value
            propagate_at_launch = true
        }
    }
}