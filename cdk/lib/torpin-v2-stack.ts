import { join } from 'path';
import { CfnOutput, Duration, RemovalPolicy, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Architecture, Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { CfnBasePathMapping, EndpointType, LambdaIntegration, RestApi } from 'aws-cdk-lib/aws-apigateway';
import { AttributeType, BillingMode, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';

export interface TorpinV2StackProps extends StackProps {
  apiStageName: string;
  customDomainBasePath?: string;
  environmentName: 'prod' | 'stage';
  scheduleEnabled: boolean;
  tableName: string;
}

export class TorpinV2Stack extends Stack {
  constructor(scope: Construct, id: string, props: TorpinV2StackProps) {
    super(scope, id, props);

    const table = new Table(this, 'TorpinTable', {
      tableName: props.tableName,
      partitionKey: { name: 'recordType', type: AttributeType.STRING },
      sortKey: { name: 'date', type: AttributeType.STRING },
      billingMode: BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    const apiLambda = new Function(this, 'TorpinApi', {
      runtime: Runtime.NODEJS_22_X,
      architecture: Architecture.ARM_64,
      memorySize: 512,
      timeout: Duration.seconds(10),
      description: `API lambda for Torpin v2 (${props.environmentName})`,
      code: Code.fromAsset(
        join(
          __dirname,
          '../../api/.dist'
        )
      ),
      handler: 'index.handler',
      environment: {
        TABLE_NAME: table.tableName,
      },
    });

    table.grantReadData(apiLambda);

    const eventHandler = new Function(this, 'EventHandlerLambda', {
      runtime: Runtime.PROVIDED_AL2,
      architecture: Architecture.ARM_64,
      memorySize: 512,
      timeout: Duration.seconds(10),
      description: `Event-driven updater for Torpin v2 sessions (${props.environmentName})`,
      code: Code.fromAsset(
        join(
          __dirname,
          '../../lambda-v2/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/EventHandlerV2Lambda/EventHandlerV2Lambda.zip'
        )
      ),
      handler: 'main',
      environment: {
        STEAM_API_KEY: process.env.STEAM_API_KEY || '',
        STEAM_ID: process.env.STEAM_ID || '',
        TABLE_NAME: table.tableName,
      },
    });

    const rule = new Rule(this, 'EveryMinuteRule', {
      enabled: props.scheduleEnabled,
      schedule: Schedule.rate(Duration.minutes(1)),
    });
    rule.addTarget(new LambdaFunction(eventHandler));

    table.grantReadWriteData(eventHandler);

    const api = new RestApi(this, 'TorpinApiGateway', {
      restApiName: `Is Brian Torpin Status Service v2 (${props.environmentName})`,
      description: 'This service checks if Brian is playing World of Warships.',
      endpointConfiguration: {
        types: [EndpointType.REGIONAL],
      },
      deployOptions: {
        stageName: props.apiStageName,
      },
    });

    api.root.addMethod('GET', new LambdaIntegration(apiLambda));

    if (props.customDomainBasePath) {
      new CfnBasePathMapping(this, 'CustomDomainMapping', {
        basePath: props.customDomainBasePath,
        domainName: 'api.isbriantorp.in',
        restApiId: api.restApiId,
        stage: api.deploymentStage.stageName,
      });
    }

    new CfnOutput(this, 'ApiFunctionName', {
      value: apiLambda.functionName,
    });

    new CfnOutput(this, 'ApiUrl', {
      value: props.customDomainBasePath
        ? `https://api.isbriantorp.in/${props.customDomainBasePath}`
        : api.url,
    });

    new CfnOutput(this, 'EventHandlerFunctionName', {
      value: eventHandler.functionName,
    });

    new CfnOutput(this, 'TableName', {
      value: table.tableName,
    });
  }
}
