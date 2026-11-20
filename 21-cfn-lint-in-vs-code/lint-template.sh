#!/bin/bash
# lint-template.sh
# Lint the broken template, optionally your own template, and compare
# with validate-template.
# Run in a terminal from the folder that holds broken-network-template.yaml.
# Nothing is created in AWS.
#
# Usage:
#   bash lint-template.sh                     (only the broken template)
#   bash lint-template.sh <your-template>.yaml (also lint your own template)

# Check that Python and cfn-lint are installed
python --version
cfn-lint --version

# Lint the broken template (expect the deliberate errors)
cfn-lint broken-network-template.yaml

# Lint your own template, if given (warnings may appear even if it deploys fine)
if [ -n "$1" ]; then
  cfn-lint "$1"
fi

# Ask CloudFormation to validate the broken template.
# Note: the misspelled property CidrBlok is not caught here.
aws cloudformation validate-template \
  --template-body file://broken-network-template.yaml
