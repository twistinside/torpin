import { join } from 'path';
import { Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { AccessLogFormat, CfnAccount, DomainName, EndpointType, LambdaIntegration, LogGroupLogDestination, MethodLoggingLevel, RestApi } from 'aws-cdk-lib/aws-apigateway';
import { Certificate, CertificateValidation } from 'aws-cdk-lib/aws-certificatemanager';
import { ARecord, HostedZone, RecordTarget } from 'aws-cdk-lib/aws-route53';
import { ApiGatewayDomain } from 'aws-cdk-lib/aws-route53-targets';
import { Role, ServicePrincipal, ManagedPolicy } from 'aws-cdk-lib/aws-iam';
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs';

export class TorpinStack extends Stack {

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // Create Lambda function
    const myLambda = new Function(this, 'TorpinApi', {
      runtime: Runtime.PROVIDED_AL2023,
      code: Code.fromAsset(join(__dirname, '../../lambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/TorpinServiceLambda/TorpinServiceLambda.zip')),
      handler: 'main',
      environment: {
          STEAM_API_KEY: process.env.STEAM_API_KEY || '',
      },
    });

    // Create an IAM Role for API Gateway to push logs to CloudWatch
    const apiGatewayCloudWatchRole = new Role(this, 'ApiGatewayCloudWatchRole', {
      assumedBy: new ServicePrincipal('apigateway.amazonaws.com'),  // API Gateway Service Principal
    });

    // Attach the AmazonAPIGatewayPushToCloudWatchLogs policy to the role
    apiGatewayCloudWatchRole.addManagedPolicy(
      ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonAPIGatewayPushToCloudWatchLogs')
    );

    // Set the CloudWatch log role ARN in API Gateway's Account Settings
    new CfnAccount(this, 'ApiGatewayAccount', {
      cloudWatchRoleArn: apiGatewayCloudWatchRole.roleArn,  // Use the created role's ARN
    });

    // Create a new Hosted Zone for the domain
    const hostedZone = new HostedZone(this, 'HostedZone', {
      zoneName: 'isbriantorp.in',  // Replace with your domain name
    });

    // Create CloudWatch Log Group
    const logGroup = new LogGroup(this, 'ApiGatewayAccessLogs', {
      retention: RetentionDays.ONE_WEEK,  // Set retention as needed
    });

    // Create API Gateway
    const api = new RestApi(this, 'ToprinApiGateway', {
      restApiName: 'Is Brian Torpin Status Service',
      description: 'This service checks if Brian is playing World of Warships.',
      endpointConfiguration: {
        types: [EndpointType.REGIONAL] // Force Regional API
      },
      deployOptions: {
        // Enable CloudWatch Logs and set access log destination to the log group
        accessLogDestination: new LogGroupLogDestination(logGroup),
        accessLogFormat: AccessLogFormat.jsonWithStandardFields({
          caller: true,
          httpMethod: true,
          ip: true,
          protocol: true,
          requestTime: true,
          resourcePath: true,
          responseLength: true,
          status: true,
          user: true,
        }),
        loggingLevel: MethodLoggingLevel.INFO,  // Set logging level
        dataTraceEnabled: true,  // Log request and response data
      },
    });

    // Add resources to the API
    const apiResource = api.root.addResource('v1');

    // Integrating Lambda with API Gateway
    const lambdaIntegration = new LambdaIntegration(myLambda);
    apiResource.addMethod('GET', lambdaIntegration);

   // Request or Import SSL Certificate for your custom domain
    const certificate = new Certificate(this, 'Certificate', {
      domainName: 'api.isbriantorp.in',  // Replace with your subdomain
      validation: CertificateValidation.fromDns(hostedZone),  // DNS validation with the hosted zone
    });

    // Create a custom domain for API Gateway
    const customDomain = new DomainName(this, 'CustomDomain', {
      domainName: 'api.isbriantorp.in', 
      certificate: certificate,
      endpointType: EndpointType.REGIONAL,  // Ensure it's Regional
    });

    // Map custom domain to the API Gateway stage
    customDomain.addBasePathMapping(api, { basePath: '' });

    // Create an A Record in Route 53 for the custom domain
    new ARecord(this, 'ApiARecord', {
      zone: hostedZone,
      target: RecordTarget.fromAlias(new ApiGatewayDomain(customDomain)),
      recordName: 'api',
    });
  }
}