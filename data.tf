# Data Sources

data "aws_availability_zones" "available" {
  state = "available"
}

# DYNAMIC VERSION CHECK
# This script asks AWS: "What are all the valid cluster versions you support?"
# This ensures that it will pick the latest one.
data "external" "latest_k8s_version" {
  program = ["bash", "-c", <<EOT
    ver=$(aws eks describe-addon-versions --addon-name vpc-cni \
      --query 'addons[].addonVersions[].compatibilities[].clusterVersion' \
      --output text | tr '\t' '\n' | sort -V | tail -n 1)
    echo "{\"version\": \"$ver\"}"
  EOT
  ]
}

