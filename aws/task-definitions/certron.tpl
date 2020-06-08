[
  {
    "name": "certron",
    "image": "${image}:${tag}",
    "cpu": 1024,
    "memory": 4096,
    "user": "certron",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${logGroup}",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "${tag}"
        }
    }
  }
]
