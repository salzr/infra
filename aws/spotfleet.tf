resource "aws_spot_fleet_request" "automata" {
  iam_fleet_role  = "arn:aws:iam::${var.aws_account_number}:role/aws-service-role/spotfleet.amazonaws.com/AWSServiceRoleForEC2SpotFleet"
  spot_price      = "0.05"
  target_capacity = 0
  valid_until     = "2033-01-01T01:00:00Z"

  launch_specification {
    ami                      = "ami-056807e883f197989"
    instance_type            = "m4.large"
    subnet_id                = var.subnet_id
    iam_instance_profile_arn = aws_iam_instance_profile.spotfleet_automata_node.arn
    user_data = <<EOF
#!/bin/bash

set -eux
mkdir -p /etc/ecs
echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
export PATH=/usr/local/bin:$PATH
yum -y install jq
easy_install pip
pip install awscli
aws configure set default.region us-east-1

cat <<EOS > /etc/init/spot-instance-termination-handler.conf
description "Start spot instance termination handler monitoring script"
author "BoltOps"
start on started ecs
script
echo \$\$ > /var/run/spot-instance-termination-handler.pid
exec /usr/local/bin/spot-instance-termination-handler.sh
end script
pre-start script
logger "[spot-instance-termination-handler.sh]: spot instance termination
notice handler started"
end script
EOS

cat <<EOS > /usr/local/bin/spot-instance-termination-handler.sh
#!/bin/bash
while sleep 5; do
if [ -z \$(curl -Isf http://169.254.169.254/latest/meta-data/spot/termination-time)]; then
/bin/false
else
logger "[spot-instance-termination-handler.sh]: spot instance termination notice detected"
STATUS=DRAINING
ECS_CLUSTER=\$(curl -s http://localhost:51678/v1/metadata | jq .Cluster | tr -d \")
CONTAINER_INSTANCE=\$(curl -s http://localhost:51678/v1/metadata | jq .ContainerInstanceArn | tr -d \")
logger "[spot-instance-termination-handler.sh]: putting instance in state \$STATUS"

/usr/local/bin/aws  ecs update-container-instances-state --cluster \$ECS_CLUSTER --container-instances \$CONTAINER_INSTANCE --status \$STATUS

logger "[spot-instance-termination-handler.sh]: putting myself to sleep..."
sleep 120 # exit loop as instance expires in 120 secs after terminating notification
fi
done
EOS

chmod +x /usr/local/bin/spot-instance-termination-handler.sh
EOF
  }

  lifecycle {
    ignore_changes = [valid_until, target_capacity]
  }

  terminate_instances_with_expiration = true
}
