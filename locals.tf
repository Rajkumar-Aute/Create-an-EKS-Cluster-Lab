# Locals
locals {
  # Select the first 3 availability zones in the region
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}