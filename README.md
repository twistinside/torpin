# Torpin'

[![Torpin Service Lambda](https://github.com/twistinside/torpin/actions/workflows/deploy.yaml/badge.svg)](https://github.com/twistinside/torpin/actions/workflows/deploy.yaml)

This project was launched as a learning opportunity, primarily for Swift Lambdas, but also for creating and deploying a full stack project with as much automation as possible. I am very happy with the outcome... This project is as fully CI/CD as I could manage (a note on the single challenge is below), and I have learned sp much about managing multiple parts of the stack in a single package.

The impetus for this project is my friend's love of World of Warships, and our inside joke that if you check at any particular time of day, he is probably playing. The game is a multiplayer game where you captain a ship and try to sink you opponents, and Torpin' refers to shooting torpedos at the other players.

# Architecture

This project consists of three submodules: a Swift AWS Lambda package, a CDK package to deploy it, and the website that calls the backend and displays the data returned.

## AWS Swift Lambdas

The backend consists of two lambdas, one triggered by API Gateway and one triggered by EventBridge events, and they are backed by a DynamoDB database.

### Getting Torpin' Status
The EventBridge trigger fires every minute, triggering a lambda that calls the Steam API to determine if Brian is playing World of Warships. The torpin' status is then stored in DynamoDB as a `Session`. Each `Session` consists of a start and end time. Every `Session` has a start time, and a `Session` is considered active if there is no end time.

If Brian is online and playing World of Warships, the lambda will check for an active `Session`. If none is present, a new one will be created. If he is not online or not playing World of Warships, the lambda will check for an active `Session`. If none is present, nothing is done. If one is found, an end time is added, closing the session.

### Vending Torpin' Status

When the API is called, the lambda checks for an active `Session`. If one is found, it returns `true`.

### Architecture considerations

The database is called from two lambdas, but is only written to by one. The lambda triggered by API Gateway is read only, so there is no opportunity for a race condition.

Calls to the Steam API are only done by the lambda triggered by EventBridge. This guarantees minimal traffic with my API key. Disintermediating API Gateway and Steam API calls both speeds up torpin API calls and prevents abusive traffic from spamming calls to Steam.

## CDK

The project's resources are all deployable as infrastructure-as-code. This enables me to automate deployments and rebuild the entire system trivially if needed. The only challenge with fully deploying a clean website is ensuring that I can set record for my website. That is a manual step that has to happen once on a full redeploy.

## Astro Website

The project's website is built using Astro. This is probably overkill for this use case, but I had some experience with the framework from another project and wanted to keep using it.

The website is hosted on Porkbun, my DSN, and deployed via FTP upload in the action that runs on push to main.

## GitHub

The site is hosted in Github, and deployed using GitHub actions.
