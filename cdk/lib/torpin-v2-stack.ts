import { join } from 'path';
import { CfnOutput, Duration, RemovalPolicy, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Certificate } from 'aws-cdk-lib/aws-certificatemanager';
import {
  AllowedMethods,
  CacheCookieBehavior,
  CacheHeaderBehavior,
  CachePolicy,
  CacheQueryStringBehavior,
  Distribution,
  Function as CloudFrontFunction,
  FunctionCode,
  FunctionEventType,
  OriginRequestPolicy,
  ResponseHeadersPolicy,
  ViewerProtocolPolicy,
} from 'aws-cdk-lib/aws-cloudfront';
import { HttpOrigin, S3BucketOrigin } from 'aws-cdk-lib/aws-cloudfront-origins';
import { Architecture, Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { AttributeType, BillingMode, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';
import { BlockPublicAccess, Bucket, BucketEncryption } from 'aws-cdk-lib/aws-s3';
import { BucketDeployment, CacheControl, Source } from 'aws-cdk-lib/aws-s3-deployment';

export interface TorpinV2StackProps extends StackProps {
  cloudFrontCertificateArn?: string;
  customDomainName?: string;
  environmentName: 'prod' | 'stage';
  legacyApiDomainName: string;
  legacyApiOriginPath: string;
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

    const statusCacheBucket = new Bucket(this, 'StatusCacheBucket', {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryption: BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    const eventHandler = new Function(this, 'EventHandlerLambda', {
      runtime: Runtime.PROVIDED_AL2023,
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
        STATUS_CACHE_BUCKET: statusCacheBucket.bucketName,
        TABLE_NAME: table.tableName,
      },
    });

    const rule = new Rule(this, 'EveryMinuteRule', {
      enabled: props.scheduleEnabled,
      schedule: Schedule.rate(Duration.minutes(1)),
    });
    rule.addTarget(new LambdaFunction(eventHandler));

    table.grantReadWriteData(eventHandler);
    statusCacheBucket.grantPut(eventHandler, 'status.json');
    statusCacheBucket.grantPut(eventHandler, 'v2*');

    const normalizeStatusPath = new CloudFrontFunction(this, 'NormalizeStatusPathFunction', {
      code: FunctionCode.fromInline(`
function handler(event) {
  var request = event.request;
  if (request.uri === '/v2' || request.uri === '/v2/') {
    request.uri = '/status.json';
  }
  return request;
}
      `),
    });
    const statusCachePolicy = new CachePolicy(this, 'StatusCachePolicy', {
      cookieBehavior: CacheCookieBehavior.none(),
      defaultTtl: Duration.seconds(60),
      enableAcceptEncodingBrotli: true,
      enableAcceptEncodingGzip: true,
      headerBehavior: CacheHeaderBehavior.none(),
      maxTtl: Duration.seconds(60),
      minTtl: Duration.seconds(0),
      queryStringBehavior: CacheQueryStringBehavior.none(),
    });
    const statusBehavior = {
      allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
      cachePolicy: statusCachePolicy,
      functionAssociations: [
        {
          eventType: FunctionEventType.VIEWER_REQUEST,
          function: normalizeStatusPath,
        },
      ],
      origin: S3BucketOrigin.withOriginAccessControl(statusCacheBucket),
      responseHeadersPolicy: ResponseHeadersPolicy.CORS_ALLOW_ALL_ORIGINS,
      viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    };
    const legacyBehavior = {
      allowedMethods: AllowedMethods.ALLOW_ALL,
      cachePolicy: CachePolicy.CACHING_DISABLED,
      origin: new HttpOrigin(props.legacyApiDomainName, {
        originPath: props.legacyApiOriginPath,
      }),
      originRequestPolicy: OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
      viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    };
    const cloudFrontCertificate = props.cloudFrontCertificateArn
      ? Certificate.fromCertificateArn(this, 'CloudFrontCertificate', props.cloudFrontCertificateArn)
      : undefined;
    const distribution = new Distribution(this, 'TorpinApiDistribution', {
      additionalBehaviors: {
        'v1/*': legacyBehavior,
        'v2*': statusBehavior,
      },
      certificate: cloudFrontCertificate,
      comment: `Low-latency Torpin API front door (${props.environmentName})`,
      defaultBehavior: legacyBehavior,
      domainNames: cloudFrontCertificate && props.customDomainName ? [props.customDomainName] : undefined,
    });

    new BucketDeployment(this, 'InitialStatusCacheDeployment', {
      cacheControl: [
        CacheControl.setPublic(),
        CacheControl.maxAge(Duration.seconds(60)),
        CacheControl.sMaxAge(Duration.seconds(60)),
      ],
      contentType: 'application/json',
      destinationBucket: statusCacheBucket,
      distribution,
      distributionPaths: ['/v2', '/v2/'],
      prune: false,
      sources: [
        Source.jsonData('status.json', { isBrianTorpin: false }),
      ],
    });

    new CfnOutput(this, 'ApiUrl', {
      value: cloudFrontCertificate && props.customDomainName
        ? `https://${props.customDomainName}/v2`
        : `https://${distribution.distributionDomainName}/v2`,
    });

    new CfnOutput(this, 'DistributionDomainName', {
      value: distribution.distributionDomainName,
    });

    new CfnOutput(this, 'EventHandlerFunctionName', {
      value: eventHandler.functionName,
    });

    new CfnOutput(this, 'TableName', {
      value: table.tableName,
    });

    new CfnOutput(this, 'StatusCacheBucketName', {
      value: statusCacheBucket.bucketName,
    });
  }
}
