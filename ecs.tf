resource "aws_ecs_cluster" "main" {
  name = "genea-work-cluster"
}

resource "aws_ecr_repository" "microservice" {
  name = "microservice"
}

resource "aws_lb" "alb" {
  name               = "microservice-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "microservice" {
  name        = "tg-microservice"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "listener_microservice" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservice.arn
  }
}

resource "aws_ecs_task_definition" "microservice" {
  family                   = "microservice"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "microservice"
      image        = "${aws_ecr_repository.microservice.repository_url}:latest"
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      secrets = [
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:dbname::" }
        { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:host::" },
        { name = "DB_USERNAME", valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:password::" },
      ]
    }
  ])
}

resource "aws_ecs_service" "microservice" {
  name            = "microservice"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.microservice.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservice.arn
    container_name   = "microservice"
    container_port   = 3000
  }
}