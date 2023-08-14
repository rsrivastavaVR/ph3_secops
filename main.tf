provider "aws" {
  region = "us-east-2"
}







# IAM Roles

resource "aws_iam_role" "s3_versioning_lambda" {
    name = "s3_versioning_lambda"
    assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "s3_versioning_remediation" {
    name = "s3_versioning_remediation"
    assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "s3_versioning_remediation_lambda" {
    name = "s3_versioning_remediation_lambda"
    assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "s3_versioning_config" {
    name = "s3_versioning_config"
    assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}








# IAM Policy Attachments

resource "aws_iam_policy_attachment" "s3_versioning_lambda" {
    name = "s3_versioning_lambda"
    for_each = toset([
        "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", 
        "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
        ])
    roles = [aws_iam_role.s3_versioning_lambda.name]
    policy_arn = each.value
}

resource "aws_iam_policy_attachment" "s3_versioning_config" {
    name = "s3_versioning_config"
    roles = [aws_iam_role.s3_versioning_config.name]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
}

resource "aws_iam_policy_attachment" "s3_versioning_remediation" {
    name = "s3_versioning_remediation"
    for_each = toset([
        "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
        ])
    roles = [aws_iam_role.s3_versioning_remediation.name]
    policy_arn = each.value
}

resource "aws_iam_policy_attachment" "s3_versioning_remediation_lambda" {
    name = "s3_versioning_remediation_lambda"
    for_each = toset([
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        ])
    roles = [aws_iam_role.s3_versioning_remediation_lambda.name]
    policy_arn = each.value
}






# Lambda definition to check versioning and Config rule definition

resource "aws_lambda_function" "s3_versioning" {
    filename = "s3_versioning.zip"
    function_name = "s3-versioning"
    role = aws_iam_role.s3_versioning_lambda.arn
    handler = "s3_versioning.lambda_handler"
    runtime = "python3.11"

}

resource "aws_config_config_rule" "s3_versioning" {
    name = "s3_versioning"
    
    source {
        owner = "CUSTOM_LAMBDA"
        source_identifier = aws_lambda_function.s3_versioning.arn
        source_detail {
            message_type = "ConfigurationItemChangeNotification"
        }
        source_detail {
            message_type = "OversizedConfigurationItemChangeNotification"
        }
    }

    scope {
        compliance_resource_types = ["AWS::S3::Bucket"]
    }    
}

resource "aws_lambda_permission" "s3_versioning_permission" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.s3_versioning.arn
    principal     = "config.amazonaws.com"
    statement_id  = "AllowExecutionFromConfig"
}

# resource "aws_config_configuration_recorder" "s3_versioning_config" {
#   name     = "s3_versioning_config"
#   role_arn = aws_iam_role.s3_versioning_config.arn
# }



# Auto-Remediation document and function definition for Config rule

resource "aws_ssm_document" "AutoRemediationS3Versioning" {
    name = "AutoRemediationS3Versioning"
    document_format = "YAML"
    document_type   = "Automation"

    content = file("AutoRemediationS3Versioning.yaml")

}

resource "aws_lambda_function" "s3_versioning_remediation" {
    filename = "s3_versioning_remediation.zip"
    function_name = "s3-versioning-remediation"
    role = aws_iam_role.s3_versioning_remediation_lambda.arn
    handler = "s3_versioning_remediation.lambda_handler"
    runtime = "python3.11"

}

resource "aws_config_remediation_configuration" "s3_versioning_remediation" {
  config_rule_name = aws_config_config_rule.s3_versioning.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AutoRemediationS3Versioning"
  target_version   = "1"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.s3_versioning_remediation.arn
  }
  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
}





# Conformance Pack definition

resource "aws_config_conformance_pack" "s3_versioning_conformance_pack" {
    name = "S3VersioningConformancePack"
    template_body = <<EOT
    Resources:
        S3Versioning:
            Type: AWS::Config::ConfigRule
            Properties:
            ConfigRuleName: "s3_versioning"
            Scope:
                ComplianceResourceTypes:
                - "AWS::S3::Bucket"
            Source:
                Owner: "CUSTOM_LAMBDA"
                SourceDetails:
                -
                    EventSource: "aws.config"
                    MessageType: "ConfigurationItemChangeNotification"
                -
                    EventSource: "aws.config"
                    MessageType: "OversizedConfigurationItemChangeNotification"
                SourceIdentifier:
                Ref: ${aws_lambda_function.s3_versioning.arn}
    EOT
}








# EXTRA 

# resource "aws_iam_policy" "s3_versioning_lambda" {
#     name = "s3_versioning_lambda"
#     policy = file("s3_versioning_lambda.json")
# }

# resource "aws_iam_policy" "s3_versioning_remediation" {
#     name = "s3_versioning_remediation"
#     policy = file("s3_versioning_remediation.json")
# }

# resource "aws_iam_policy" "s3_versioning_remediation_lambda" {
#     name = "s3_versioning_remediation_lambda"
#     policy = file("s3_versioning_remediation_lambda.json")
# }