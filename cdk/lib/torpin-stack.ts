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
    
    // Create a new Hosted Zone for the domain
    const hostedZone = new HostedZone(this, 'HostedZone', {
      zoneName: 'isbriantorp.in',  // Replace with your domain name
    });

    // Create API Gateway
    const api = new RestApi(this, 'ToprinApiGateway', {
      restApiName: 'Is Brian Torpin Status Service',
      description: 'This service checks if Brian is playing World of Warships.',
      endpointConfiguration: {
        types: [EndpointType.REGIONAL] // Force Regional API
      }
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
    customDomain.addBasePathMapping(api, { basePath: 'v1' });
    
    // Create an A Record in Route 53 for the custom domain
    new ARecord(this, 'ApiARecord', {
      zone: hostedZone,
      target: RecordTarget.fromAlias(new ApiGatewayDomain(customDomain)),
      recordName: 'api',
    });
  }
}