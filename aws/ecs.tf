resource "aws_ecs_cluster" "automata" {
  name               = "automata"
  capacity_providers = ["FARGATE_SPOT"]
}
