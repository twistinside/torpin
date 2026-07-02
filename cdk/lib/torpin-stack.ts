import { join } from 'path';
import { CfnOutput, Duration, RemovalPolicy, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Architecture, Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { DomainName, EndpointType, LambdaIntegration, RestApi } from 'aws-cdk-lib/aws-apigateway';
import { Certificate, CertificateValidation } from 'aws-cdk-lib/aws-certificatemanager';
import { AttributeType, BillingMode, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';

export class TorpinStack extends Stack {
  public readonly api: RestApi;

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const table = new Table(this, 'TorpinTable', {
      tableName: 'Torpin',
      partitionKey: { name: 'recordType', type: AttributeType.STRING },
      sortKey:      { name: 'date', type: AttributeType.STRING },
      billingMode:  BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    const apiLambda = new Function(this, 'TorpinApi', {
      runtime: Runtime.PROVIDED_AL2023,
      architecture: Architecture.ARM_64,
      memorySize: 512,
      timeout: Duration.seconds(10),
      description: 'API lambda for Torpin status',
      code: Code.fromAsset(
        join(
          __dirname,
          '../../lambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/TorpinServiceLambda/TorpinServiceLambda.zip'
        )
      ),
      handler: 'main',
      environment: {
        STEAM_API_KEY: process.env.STEAM_API_KEY || '',
        STEAM_ID: process.env.STEAM_ID || '',
      },
    });

    table.grantReadData(apiLambda);

    const eventHandler = new Function(this, 'EventHandlerLambda', {
      runtime: Runtime.PROVIDED_AL2023,
      architecture: Architecture.ARM_64,
      memorySize: 512,
      timeout: Duration.seconds(10),
      description: 'Event-driven updater for Torpin sessions',
      code: Code.fromAsset(
        join(
          __dirname,
          '../../lambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/EventHandlerLambda/EventHandlerLambda.zip'
        )
      ),
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

    this.api = new RestApi(this, 'ToprinApiGateway', {
      restApiName: 'Is Brian Torpin Status Service',
      description: 'This service checks if Brian is playing World of Warships.',
      endpointConfiguration: {
        types: [EndpointType.REGIONAL] // Force Regional API
      },
    });

    const apiResource = this.api.root.addResource('v1');

    const lambdaIntegration = new LambdaIntegration(apiLambda);
    apiResource.addMethod('GET', lambdaIntegration);

    new CfnOutput(this, 'ExportsOutputRefToprinApiGatewayCAC85CDFD3277779', {
      exportName: 'TorpinStack:ExportsOutputRefToprinApiGatewayCAC85CDFD3277779',
      value: this.api.restApiId,
    });

    new CfnOutput(this, 'ExportsOutputRefToprinApiGatewayDeploymentStageprod8AAE6324E7284805', {
      exportName: 'TorpinStack:ExportsOutputRefToprinApiGatewayDeploymentStageprod8AAE6324E7284805',
      value: this.api.deploymentStage.stageName,
    });

    const certificate = new Certificate(this, 'Certificate', {
      domainName: 'api.isbriantorp.in',
      validation: CertificateValidation.fromDns(),
    });

    const customDomain = new DomainName(this, 'CustomDomain', {
      domainName: 'api.isbriantorp.in', 
      certificate: certificate,
      endpointType: EndpointType.REGIONAL,  // Ensure it's Regional
    });

    customDomain.addBasePathMapping(this.api, { basePath: '' });
  }
}
