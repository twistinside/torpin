# Swift Guidance

## Backend Versions
- `/v1` is the legacy live backend. Keep it running, but do not change it unless the task explicitly calls for legacy `/v1` work.
- `/v2` is the active backend development target.
- `GET /v1/` keeps the legacy response contract.
- `GET /v2` returns `{"isBrianTorpin": boolean, "recentlyTorpedAt": string | null, "torpedForInSeconds": number | null}`.

## Backend Ownership
- `lambda/` is the legacy Swift package for `/v1`.
- `lambda-v2/` is the separate Swift package for the `/v2` EventBridge handler and uses the newer Swift Lambda runtime API.
- `api/` is the JavaScript Lambda for the `/v2` API.
- Do not overlap new `/v2` backend work into existing `/v1` Swift files unless explicitly requested.

## Infrastructure Ownership
- `cdk/lib/torpin-stack.ts` owns the legacy `/v1` infrastructure.
- `cdk/lib/torpin-v2-stack.ts` owns the `/v2` infrastructure.
- `/v2` has separate `stage` and `prod` environments.
- `stage` uses the API Gateway execute-api URL only.
- `prod` is exposed at `https://api.isbriantorp.in/v2`.

## Deployment Rules
- Legacy `/v1` remains live but is not deployed through GitHub Actions anymore.
- `v2` stage deploys through `.github/workflows/deploy-backend-v2-stage.yaml`.
- `v2` prod deploys through `.github/workflows/deploy-backend-v2-prod.yaml`.
- Keep `/v1` stable while iterating on `/v2`.

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
