# Swift Guidance

## Backend Versions
- `/v1` is the legacy live backend. Keep it running, but do not change it unless the task explicitly calls for legacy `/v1` work.
- `/v2` is the active backend development target.
- `GET /v1/` keeps the legacy response contract.
- `GET /v2` returns `{"isBrianTorpin": boolean}` from the static status cache.
- CloudFront must serve both `/v2` and `/v2/` from the static status cache.
- CloudFront must keep `/v1/*` routed to the legacy API Gateway origin for compatibility.

## Backend Ownership
- `lambda/` is the legacy Swift package for `/v1`.
- `lambda-v2/` is the separate Swift package for the `/v2` EventBridge handler and uses the newer Swift Lambda runtime API.
- `api/` is the retired JavaScript Lambda package that previously served `/v2`; do not route new `/v2` traffic through it.
- Do not overlap new `/v2` backend work into existing `/v1` Swift files unless explicitly requested.

## Infrastructure Ownership
- `cdk/lib/torpin-stack.ts` owns the legacy `/v1` infrastructure.
- `cdk/lib/torpin-v2-stack.ts` owns the `/v2` infrastructure.
- `/v2` has separate `stage` and `prod` environments.
- `stage` uses the CloudFront distribution URL only.
- `prod` is exposed at `https://api.isbriantorp.in/v2`.
- The v2 CloudFront legacy origin must be configured from `legacyApiDomainName` and `legacyApiOriginPath` strings, not from a CDK reference to `TorpinStack`.
- Do not make `TorpinV2StageStack` or `TorpinV2ProdStack` depend on `TorpinStack`; v2 deploys must not update legacy Lambda resources.
- The default CDK app synth/deploy path includes only v2 stacks. Use `INCLUDE_LEGACY_STACK=true` only when intentionally working on legacy `/v1` infrastructure.

## Deployment Rules
- Legacy `/v1` remains live but is not deployed through GitHub Actions anymore.
- `v2` stage deploys through `.github/workflows/deploy-backend-v2-stage.yaml`.
- `v2` prod deploys through `.github/workflows/deploy-backend-v2-prod.yaml`.
- Keep `/v1` stable while iterating on `/v2`.
- v2 deploy workflows must package and deploy only `lambda-v2/`; do not add placeholder or real `lambda/` packaging steps to v2 deploy workflows.
- Keep v1-related PR workflow triggers active for `lambda/**` and legacy CDK-relevant changes even though v1 is not deployed by GitHub Actions.
- Production CloudFront needs `CLOUDFRONT_CERTIFICATE_ARN` for a us-east-1 ACM certificate covering `api.isbriantorp.in`.
- DNS for `api.isbriantorp.in` is manual and should point to the prod CloudFront distribution after cutover.

## Nova Tasks
- Use `.nova/Tasks/Torpin Service Lambda v2.json` for the `lambda-v2/` package.
- Use `.nova/Tasks/Torpin Service CDK Stack v2.json` for the `/v2` CDK stacks.

## Unit Tests
- Test files shall be created with a 1:1 relationship to the files under test.
- Those files shall be created in a file structure that matches the file structure of the file under test.
- Test shall be located in the `Tests` folder at the same level as the `Sources` folder in the package.

## Ordering Properties
- Properties shall be listed in an orderly fashion, static first, private first, let first... So static private let comes before public let, etc...
- Properties shall be ordered alphabetically within the above ordering.
