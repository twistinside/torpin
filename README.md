# Torpin'

[![Deploy Backend v2 Stage](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-stage.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-stage.yaml) [![Deploy Backend v2 Prod](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-prod.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-backend-v2-prod.yaml) [![Deploy Website](https://github.com/twistinside/torpin/actions/workflows/deploy-website.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy-website.yaml)

This project was launched as a learning opportunity, primarily for Swift Lambdas, but also for creating and deploying a full stack project with as much automation as possible. I am very happy with the outcome. The project now runs two backend generations in parallel: legacy `/v1`, and a staged `/v2` rollout that moves the API Lambda to Node.js while keeping the timer-driven Steam polling Lambda in Swift.

The impetus for this project is my friend's love of World of Warships, and our inside joke that if you check at any particular time of day, he is probably playing. The game is a multiplayer game where you captain a ship and try to sink you opponents, and Torpin' refers to shooting torpedos at the other players.

You can find the site here: https://isbriantorp.in

# Architecture

This project consists of five submodules:
1. a legacy Swift backend package in `lambda/` that still serves `/v1`
2. a Node.js API package in `api/` that serves the new `/v2` endpoint
3. a separate Swift EventBridge Lambda package in `lambda-v2/` that records state for `/v2`
4. a CDK package in `cdk/` that deploys both backend generations
5. the Astro website in `astro/` that consumes the backend

<p align="center">
<img width="627" height="344" alt="Screenshot 2025-07-21 at 1 58 39 PM" src="https://github.com/user-attachments/assets/0a04aad9-e5bb-41f2-a437-39f09fa59d7a" />
</p>

## AWS Lambdas and Versions

The live system now has two backend generations:

1. `v1`
   Keeps the original public endpoint at `https://api.isbriantorp.in/v1/` running unchanged from the legacy Swift package in `lambda/`.
2. `v2`
   Adds a parallel backend with separate `stage` and `prod` environments. The `v2` API is served by a Node.js Lambda, and the timer-driven updater runs from the separate `lambda-v2/` Swift package on the current runtime API.

Both generations are backed by DynamoDB. `v2` stage and `v2` prod use separate tables so they can be tested independently.

### Getting Torpin' Status
The EventBridge trigger fires every minute, triggering a lambda that calls the Steam API to determine if my friend is playing World of Warships. The torpin' status is then stored in DynamoDB as a `Session`. Each `Session` consists of a start and end time. Every `Session` has a start time, and a `Session` is considered active if there is no end time.

If my friend is online and playing World of Warships, the lambda will check for an active `Session`. If none is present, a new one will be created. If he is not online or not playing World of Warships, the lambda will check for an active `Session`. If none is present, nothing is done. If one is found, an end time is added, closing the session.

### Vending Torpin' Status

The API surface is versioned:

1. `v1`
   When the API is called, the legacy Swift Lambda checks for an active `Session`. If one is found, it returns `{"isBrianTorpin": true}`.
2. `v2`
   The new Node.js Lambda reads the newest `sessionRecord` and returns:

   `{"isBrianTorpin": boolean, "recentlyTorpedAt": string | null, "torpedForInSeconds": number | null}`

   If Brian is currently torpin', `recentlyTorpedAt` is "now" and `torpedForInSeconds` reflects the active session length. If the latest session is closed, `recentlyTorpedAt` is the session end time and `torpedForInSeconds` is the session duration.

### Architecture considerations

The database is called from two lambdas, but is only written to by one. The lambda triggered by API Gateway is read only, so there is no opportunity for a race condition.

Calls to the Steam API are only done by the Swift lambda triggered by EventBridge. This guarantees minimal traffic with my API key. Disintermediating API Gateway and Steam API calls both speeds up torpin API calls and prevents abusive traffic from spamming calls to Steam.

## CDK

The project's resources are all deployable as infrastructure-as-code. This enables me to automate deployments and rebuild the entire system trivially if needed. The only challenge with fully deploying a clean website is ensuring that I can set record for my website. That is a manual step that has to happen once on a full redeploy.

## Astro Website

The project's website is built using Astro. This is probably overkill for this use case, but I had some experience with the framework from another project and wanted to keep using it.

The website is hosted on Porkbun, my DSN, and deployed via FTP upload in the action that runs on push to main.

## GitHub

The site's code is hosted in Github and deployed using GitHub Actions.

`v2` backend deployments are intentionally split:
1. pushes to `main` deploy `v2` stage
2. `v2` prod is deployed manually through an approved workflow
3. legacy `v1` stays live until the newer backend is proven out

# Lessons Learned

## Coding in Swift for AWS

Swift lambdas are as easy to work with as the Java lambdas I write at work. The [Swift AWS Lambda Runtime](https://github.com/swift-server/swift-aws-lambda-runtime) and [Swift AWS SDK](https://github.com/awslabs/aws-sdk-swift) are fairly well documented, but it can be challenging to find external code examples when learning.

Setting up the lambda itself is very familiar, and I have no complaints. Coding DynamoDB models, however, requires a significant amount of boilerplate code that is wonderfully abstracted away by Java annotations. This level of abstraction isn't availble to the Swift SDK yet, and would be challenging to automate without Java reflection and in a type safe manner. It's not insurmountable, but is a notable drawback.

Deploying Swift lambdas was as easy as anything in Java land using CDK, and even I don't think I'd ever want to write Swift CDK code :)

## Swift Lambda Performance and Cold Starts

I was interested in the difference in cold start times between the compiled Swift code and interpreted Java code. My hope was that loading a binary directly in the runtime would be faster than starting the JVM and loading my code, but I did not find this to be the case. Swift lambda still needs to download the binary, start the lambda runtime, and initialize AWS clients before processing can begin. These steps together are comparatively longer than any improvement caused by moving from interpreted to compiled might provide. Overall, I saw 1 - 1.5 seconds cold start time, which is longer than Java cold start times I've seen, even for comparatively more complex lambdas. AWS puts a lot of time and energy into optimizing Java, and it shows.

Bottom line, Swift lambda is totally workable and ready for use, but a longer lived container architecture would play more to Swift's strengths. I personally love the flexibility and simplicity of the lambda workflow, but cold starts remain a challenge. That tradeoff is the main reason the `/v2` API Lambda moved to Node.js while the scheduled polling Lambda stayed in Swift.

## GitHub Actions

I have been impressed with GitHub actions, and the more I use them the happier I am with them. Its an incredibly powerful and flexible tool that has been able to handle any task I need performed in my CI/CD so far. I used [act](https://github.com/nektos/act) to test my actions locally, which is great if you're using Ubuntu though it's not available for macOS runners.

Splitting my tasks into the smallest components that I can, then running each only when needed was a great move, though was only really workable once I managed to get my deployment process rully realized. Combining intelligent triggers with caching means I do the least work possible for any particular merge. I think one way to improve my workflow would be to do a minimum build on push and only deploy with a new tag. Or I just need to push less often :)

# Next Steps

At this time, the website still shows a binary torpin'/not torpin', even though `/v2` now exposes richer timing metadata. Pointing the Astro frontend at `/v2` would be a simple way to add more life to the site. "Last seen torpin' 2 days ago!" is a more impactful piece of information than simply "not torpin'".

The more ambitious expansion is to feed historic data into gen AI and generate commentary about sessions, past, present, and future. A gen AI service could be insturcted to provide commentary, predictions about when the next session might be, and an overview of most played times, for example. This would be a great way to both learn about the next big tech and provide a more delighful experience for visitors to the site.

# Final Word

I had a lot of fun on this project. I flexed a few new muscles and really enjoyed combining familiar tech like AWS and newer pursuits like Swift. Anything frontend is new to me, and going from zero to deploying a website via CI/CD using a few new (to me) techs was very exciting. I don't want to put it down yet, but need to move on to the next project now that I'm at a comfortable MVP.

Thank you for reading!
