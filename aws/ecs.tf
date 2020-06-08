resource "aws_ecs_cluster" "automata" {
  name = "automata"
}

resource "aws_ecs_task_definition" "certron" {
  family = "certron"
  execution_role_arn = aws_iam_role.ecs_task_execution_certron_role.arn
  task_role_arn = aws_iam_role.ecs_certron.arn
  container_definitions = templatefile("task-definitions/certron.tpl", {
    image = aws_ecr_repository.certron.repository_url,
    tag = var.certron_vers,
    logGroup = aws_cloudwatch_log_group.fargate_certron.name
  })
  depends_on = [
    aws_cloudwatch_log_group.fargate_certron]
}