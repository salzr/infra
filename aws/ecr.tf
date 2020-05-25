resource "aws_ecr_repository" "certron" {
  name = "certron"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "certron" {
  repository = aws_ecr_repository.certron.name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "GithubSalzrActions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_user.github_salzr.arn}"
             },
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:ListImages"
            ]
        }
    ]
}
EOF
}