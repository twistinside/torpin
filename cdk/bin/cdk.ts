#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TorpinStack } from '../lib/torpin-stack';
import { TorpinV2Stack } from '../lib/torpin-v2-stack';

const app = new cdk.App();

if (process.env.INCLUDE_LEGACY_STACK === 'true') {
  new TorpinStack(app, 'TorpinStack', {
    env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
  });
}

const legacyApiDomainName = process.env.LEGACY_API_DOMAIN_NAME ?? 'h3ewqpnbxc.execute-api.us-west-1.amazonaws.com';
const legacyApiOriginPath = process.env.LEGACY_API_ORIGIN_PATH ?? '/prod';

new TorpinV2Stack(app, 'TorpinV2StageStack', {
  environmentName: 'stage',
  legacyApiDomainName,
  legacyApiOriginPath,
  scheduleEnabled: true,
  tableName: 'TorpinV2Stage',
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});

new TorpinV2Stack(app, 'TorpinV2ProdStack', {
  cloudFrontCertificateArn: process.env.CLOUDFRONT_CERTIFICATE_ARN,
  customDomainName: 'api.isbriantorp.in',
  environmentName: 'prod',
  legacyApiDomainName,
  legacyApiOriginPath,
  scheduleEnabled: true,
  tableName: 'TorpinV2Prod',
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});
