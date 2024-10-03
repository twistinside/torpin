import { Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { DomainName, EndpointType, LambdaIntegration, RestApi } from 'aws-cdk-lib/aws-apigateway';
import { Certificate, CertificateValidation } from 'aws-cdk-lib/aws-certificatemanager';
import { ARecord, HostedZone, RecordTarget } from 'aws-cdk-lib/aws-route53';
import { ApiGatewayDomain } from 'aws-cdk-lib/aws-route53-targets';

export class TorpinStack extends Stack {
  
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // Create Lambda function
    const myLambda = new Function(this, 'TorpinApi', {
      runtime: Runtime.NODEJS_20_X,
      code: Code.fromInline(`
      exports.handler = async function(event) {
        return {
          statusCode: 200,
          body: JSON.stringify({ isBrianTorpin: false })
        };
      };
      `),
      handler: 'index.handler',
    });

    // Create API Gateway
    const api = new RestApi(this, 'ToprinApiGateway', {
      restApiName: 'Is Brian Torpin Status Service',
      description: 'This service checks if Brian is playing World of Warships.',
    });

    // Add resources to the API
    const v1 = api.root.addResource('v1');
    const apiResource = v1.addResource('api');

    // Integrating Lambda with API Gateway
    const lambdaIntegration = new LambdaIntegration(myLambda);
    apiResource.addMethod('GET', lambdaIntegration);

    // Request or Import SSL Certificate for your custom domain
    const certificate = new Certificate(this, 'Certificate', {
      domainName: 'isbriantorp.in',  // Replace with your custom domain
      validation: CertificateValidation.fromDns(),
    });

    // Create a custom domain for API Gateway
    const customDomain = new DomainName(this, 'CustomDomain', {
      domainName: 'isbriantorp.in',  // Replace with your custom domain
      certificate: certificate,
      endpointType: EndpointType.REGIONAL,
    });

    // Map custom domain to the API Gateway stage
    customDomain.addBasePathMapping(api, { basePath: 'v1' });
  }
}