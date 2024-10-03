import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

export class TorpinStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
  super(scope, id, props);

  const myLambda = new lambda.Function(this, 'TorpinApi', {
    runtime: lambda.Runtime.NODEJS_20_X,
    code: lambda.Code.fromInline(`
    exports.handler = async function(event) {
      return {
      statusCode: 200,
      body: JSON.stringify({ isBrianTorpin: false })
      };
    };
    `),
    handler: 'index.handler',
  });

  const api = new apigateway.RestApi(this, 'ToprinApiGateway', {
    restApiName: 'Is Brian Torpin Status Service',
    description: 'This service checks if Brian is playing World of Warships.',
  });

  const v1 = api.root.addResource('v1');
  const apiResource = v1.addResource('api');

  // Integrating Lambda with API Gateway
  const lambdaIntegration = new apigateway.LambdaIntegration(myLambda);
  apiResource.addMethod('GET', lambdaIntegration);
  }
}
