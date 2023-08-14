import boto3
import json

# DEFAULT_RESOURCE_TYPE = "AWS::S3::Bucket"

def evaluate_compliance(configuration_item):

    # print(configuration_item)

    bucket_name = configuration_item['resourceName']
    # print (bucket_name)

    s3_client = boto3.client('s3')

    versioning = s3_client.get_bucket_versioning(
        Bucket=bucket_name
    )

    # Scenario 1: Versioning is not Enabled:
        # Non-Compliant
    # Scenario 2: Versioning is Enabled, MFA Delete rule does not exist:
        # Non-Compliant
    # Scenario 3: Versioning is Enabled, MFA Delete rule exists but is disabled:
        # Non-Compliant
    # Scenario 4: Versioning is Enabled, MFA Delete rule exists and is enabled:
        # Compliant

    # if versioning:
    #     try:
    #         status = versioning['Status']
    #         if status == 'Enabled':
    #             compliance_type = 'COMPLIANT'
    #             annotation = 'Versioning is enabled for the S3 bucket.'
    #         else:
    #             compliance_type = 'NON_COMPLIANT'
    #             annotation = 'Versioning is suspended for the S3 bucket.'
    #     except KeyError:
    #         compliance_type = 'NON_COMPLIANT'
    #         annotation = 'Versioning is not enabled for the S3 bucket.'
    # else:
    #     compliance_type = 'NON_COMPLIANT'
    #     annotation = 'Versioning is not enabled for the S3 bucket.'


    if versioning:
        # print(versioning)
        try:
            # try to use dict.haskey() instead of try/except
            mfa_delete = versioning['MFADelete']
            if mfa_delete:
                if mfa_delete == 'Enabled':
                    compliance_type = 'COMPLIANT'
                    annotation = 'MFA Delete is enabled for the S3 bucket.'
                else:
                    compliance_type = 'NON_COMPLIANT'
                    annotation = 'MFA Delete is disabled for the S3 bucket.'
        except KeyError:
            compliance_type = 'NON_COMPLIANT'
            annotation = 'MFA Delete not enabled for the S3 bucket.'
    else:
        compliance_type = 'NON_COMPLIANT'
        annotation = 'Versioning is not enabled for the S3 bucket.'

    evaluation = dict()
    evaluation['ComplianceResourceType'] = configuration_item['resourceType']
    evaluation['ComplianceResourceId'] = configuration_item['resourceId']
    evaluation['OrderingTimestamp'] = configuration_item['configurationItemCaptureTime']
    evaluation['ComplianceType'] = compliance_type
    evaluation['Annotation'] = annotation 


    return evaluation




def lambda_handler(event, context):
    config_client = boto3.client('config')

    invoking_event = json.loads(event['invokingEvent'])
    configuration_item = invoking_event['configurationItem']

    evaluation = evaluate_compliance(configuration_item)

    evaluations = list()
    evaluations.append(evaluation)
    
    result_token = event['resultToken']

    response = config_client.put_evaluations( Evaluations=evaluations, ResultToken=event['resultToken'])

    

    # print(evaluations)
    # return evaluations