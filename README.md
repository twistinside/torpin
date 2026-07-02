# Torpin'

[![Deploy Backend v2 Stage](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-stage.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-stage.yaml) [![Deploy Backend v2 Prod](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-prod.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-prod.yaml) [![Deploy Website](https://github.com/twistinside/torpin/actions/workflows/deploy-website.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-website.yaml)

This project was launched as a learning opportunity, primarily for Swift Lambdas, but also for creating and deploying a full stack project with as much automation as possible. I am very happy with the outcome. The project now runs two backend generations in parallel: legacy `/v1`, and a low-latency `/v2` path that serves cached status from S3 through CloudFront while keeping the timer-driven Steam polling Lambda in Swift.

The impetus for this project is my friend's love of World of Warships, and our inside joke that if you check at any particular time of day, he is probably playing. The game is a multiplayer game where you captain a ship and try to sink you opponents, and Torpin' refers to shooting torpedos at the other players.

You can find the site here: https://isbriantorp.in

# Architecture

This project consists of five submodules:
1. a legacy Swift backend package in `lambda/` that still serves `/v1`
2. a retired Node.js API package in `api/` that previously served `/v2`
3. a separate Swift EventBridge Lambda package in `lambda-v2/` that records state for `/v2` and writes the static status cache
4. a CDK package in `cdk/` that deploys the legacy stack and the separate v2 stacks
5. the Astro website in `astro/` that consumes the backend

<p align="center">
<img width="627" height="344" alt="Screenshot 2025-07-21 at 1 58 39 PM" src="https://github.com/user-attachments/assets/0a04aad9-e5bb-41f2-a437-39f09fa59d7a" />
</p>

## AWS Lambdas and Versions

The live system now has two backend generations:

1. `v1`
   Keeps the original public endpoint at `https://api.isbriantorp.in/v1/` running unchanged from the legacy Swift package in `lambda/`.
2. `v2`
   Adds a parallel backend with separate `stage` and `prod` environments. The `v2` API is served from a cached S3 object through CloudFront, and the timer-driven updater runs from the separate `lambda-v2/` Swift package on the current runtime API.

Both generations are backed by DynamoDB for session history. `v2` stage and `v2` prod use separate tables and status cache buckets so they can be tested independently.

### Getting Torpin' Status
The EventBridge trigger fires every minute, triggering a lambda that calls the Steam API to determine if my friend is playing World of Warships. The torpin' status is then stored in DynamoDB as a `Session` and written to a static S3 cache object for the public `/v2` endpoint. Each `Session` consists of a start and end time. Every `Session` has a start time, and a `Session` is considered active if there is no end time.

If my friend is online and playing World of Warships, the lambda will check for an active `Session`. If none is present, a new one will be created. If he is not online or not playing World of Warships, the lambda will check for an active `Session`. If none is present, nothing is done. If one is found, an end time is added, closing the session.

### Vending Torpin' Status

The API surface is versioned:

1. `v1`
   When the API is called, the legacy Swift Lambda checks for an active `Session`. If one is found, it returns `{"isBrianTorpin": true}`.
2. `v2`
   CloudFront serves a static JSON object written by the v2 updater:

   `{"isBrianTorpin": boolean}`

The `v2` CloudFront distribution also keeps legacy compatibility by routing `/v1/*` to the existing API Gateway execute-api origin. That origin is configured as a literal HTTP origin, not as a CDK reference to the legacy `TorpinStack`, so v2 deployments do not update or package the legacy Lambda functions.

### Architecture considerations

The database is called from two lambdas, but is only written to by one. The lambda triggered by API Gateway is read only, so there is no opportunity for a race condition.

Calls to the Steam API are only done by the Swift lambda triggered by EventBridge. This guarantees minimal traffic with my API key. Disintermediating API Gateway and Steam API calls both speeds up torpin API calls and prevents abusive traffic from spamming calls to Steam.

## CDK

The project's resources are all deployable as infrastructure-as-code. This enables me to automate deployments and rebuild the entire system trivially if needed. The legacy `/v1` infrastructure lives in `cdk/lib/torpin-stack.ts`; the active `/v2` infrastructure lives in `cdk/lib/torpin-v2-stack.ts`.

By default, the CDK app synthesizes only the v2 stage and prod stacks. Set `INCLUDE_LEGACY_STACK=true` when intentionally synthesizing or deploying the legacy stack. The v2 stacks route `/v1/*` through CloudFront to the existing legacy API Gateway by domain name and origin path, which keeps the v2 deployment graph decoupled from `TorpinStack`.

Production CloudFront uses `api.isbriantorp.in` and requires a us-east-1 ACM certificate passed through `CLOUDFRONT_CERTIFICATE_ARN`. DNS is managed manually outside CDK; after a prod CloudFront deployment, `api.isbriantorp.in` must point at the prod CloudFront distribution domain.

## Astro Website

The project's website is built using Astro. This is probably overkill for this use case, but I had some experience with the framework from another project and wanted to keep using it.

The website is hosted on Porkbun, my DSN, and deployed via FTP upload in the action that runs on push to main.

## GitHub

The site's code is hosted in Github and deployed using GitHub Actions.

`v2` backend deployments are intentionally split:
1. pushes to `main` deploy `v2` stage
2. `v2` prod is deployed manually through an approved workflow
3. legacy `v1` stays live, but is not deployed by the v2 workflows

The v2 deploy workflows build and deploy only `lambda-v2/` and `TorpinV2StageStack` or `TorpinV2ProdStack`. They must not create placeholder artifacts for `lambda/`, because that can overwrite the legacy Lambda code if the legacy stack enters the v2 deployment graph. PR checks still cover legacy-relevant paths so changes to `lambda/**` or legacy CDK files are visible before merge.

# Lessons Learned

## Coding in Swift for AWS

Swift lambdas are as easy to work with as the Java lambdas I write at work. The [Swift AWS Lambda Runtime](https://github.com/swift-server/swift-aws-lambda-runtime) and [Swift AWS SDK](https://github.com/awslabs/aws-sdk-swift) are fairly well documented, but it can be challenging to find external code examples when learning.

Setting up the lambda itself is very familiar, and I have no complaints. Coding DynamoDB models, however, requires a significant amount of boilerplate code that is wonderfully abstracted away by Java annotations. This level of abstraction isn't availble to the Swift SDK yet, and would be challenging to automate without Java reflection and in a type safe manner. It's not insurmountable, but is a notable drawback.

Deploying Swift lambdas was as easy as anything in Java land using CDK, and even I don't think I'd ever want to write Swift CDK code :)

## Swift Lambda Performance and Cold Starts

I was interested in the difference in cold start times between the compiled Swift code and interpreted Java code. My hope was that loading a binary directly in the runtime would be faster than starting the JVM and loading my code, but I did not find this to be the case. Swift lambda still needs to download the binary, start the lambda runtime, and initialize AWS clients before processing can begin. These steps together are comparatively longer than any improvement caused by moving from interpreted to compiled might provide. Overall, I saw 1 - 1.5 seconds cold start time, which is longer than Java cold start times I've seen, even for comparatively more complex lambdas. AWS puts a lot of time and energy into optimizing Java, and it shows.

Bottom line, Swift lambda is totally workable and ready for use, but a longer lived container architecture would play more to Swift's strengths. I personally love the flexibility and simplicity of the lambda workflow, but cold starts remain a challenge. That tradeoff is the main reason the `/v2` read path moved to CloudFront and S3 while the scheduled polling Lambda stayed in Swift.

## GitHub Actions

I have been impressed with GitHub actions, and the more I use them the happier I am with them. Its an incredibly powerful and flexible tool that has been able to handle any task I need performed in my CI/CD so far. I used [act](https://github.com/nektos/act) to test my actions locally, which is great if you're using Ubuntu though it's not available for macOS runners.

Splitting my tasks into the smallest components that I can, then running each only when needed was a great move, though was only really workable once I managed to get my deployment process rully realized. Combining intelligent triggers with caching means I do the least work possible for any particular merge. I think one way to improve my workflow would be to do a minimum build on push and only deploy with a new tag. Or I just need to push less often :)

# Next Steps

At this time, the website still shows a binary torpin'/not torpin'. Pointing the Astro frontend at `/v2` would move it onto the lower-latency cached endpoint while keeping the same boolean display.

The more ambitious expansion is to feed historic data into gen AI and generate commentary about sessions, past, present, and future. A gen AI service could be insturcted to provide commentary, predictions about when the next session might be, and an overview of most played times, for example. This would be a great way to both learn about the next big tech and provide a more delighful experience for visitors to the site.

# Final Word

I had a lot of fun on this project. I flexed a few new muscles and really enjoyed combining familiar tech like AWS and newer pursuits like Swift. Anything frontend is new to me, and going from zero to deploying a website via CI/CD using a few new (to me) techs was very exciting. I don't want to put it down yet, but need to move on to the next project now that I'm at a comfortable MVP.

Thank you for reading!
