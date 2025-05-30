import { join } from 'path';
import { Duration, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { AccessLogFormat, CfnAccount, DomainName, EndpointType, LambdaIntegration, LogGroupLogDestination, MethodLoggingLevel, RestApi } from 'aws-cdk-lib/aws-apigateway';
import { Certificate, CertificateValidation } from 'aws-cdk-lib/aws-certificatemanager';
import { ManagedPolicy, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs';
import { AttributeType, BillingMode, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';

export class TorpinStack extends Stack {

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const table = new Table(this, 'TorpinTable', {
      tableName: 'Torpin',
      partitionKey: { name: 'recordType', type: AttributeType.STRING },
      sortKey:      { name: 'date', type: AttributeType.STRING },
      billingMode:  BillingMode.PAY_PER_REQUEST,
    });

    const myLambda = new Function(this, 'TorpinApi', {
      runtime: Runtime.PROVIDED_AL2,
      code: Code.fromAsset(join(__dirname, '../../lambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/TorpinServiceLambda/TorpinServiceLambda.zip')),
      handler: 'main',
      environment: {
          STEAM_API_KEY: process.env.STEAM_API_KEY || '',
          STEAM_ID: process.env.STEAM_ID || '',
      },
    });

    table.grantReadData(myLambda);

    const eventHandler = new Function(this, 'EventHandlerLambda', {
      runtime: Runtime.PROVIDED_AL2,
      code: Code.fromAsset(join(
        __dirname,
        '../../lambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/EventHandlerLambda/EventHandlerLambda.zip'
      )),
      handler: 'main',
      environment: {
        STEAM_API_KEY: process.env.STEAM_API_KEY || '',
        STEAM_ID: process.env.STEAM_ID || '',
      },
    });

    const rule = new Rule(this, 'EveryMinuteRule', {
      schedule: Schedule.rate(Duration.minutes(1)),
    });
    rule.addTarget(new LambdaFunction(eventHandler));

    table.grantReadWriteData(eventHandler);

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

   // Request or Import SSL Certificate for your custom domain. DNS validation
    // must be completed manually in Porkbun since Route53 is not used.
    const certificate = new Certificate(this, 'Certificate', {
      domainName: 'api.isbriantorp.in',
      validation: CertificateValidation.fromDns(),
    });

    // Create a custom domain for API Gateway
    const customDomain = new DomainName(this, 'CustomDomain', {
      domainName: 'api.isbriantorp.in', 
      certificate: certificate,
      endpointType: EndpointType.REGIONAL,  // Ensure it's Regional
    });

    // Map custom domain to the API Gateway stage
    customDomain.addBasePathMapping(api, { basePath: '' });

  }
}