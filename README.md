# pendulum-headless-browser-cluster
The repository contains IAAC for browserless microservice hosted on ECS cluster using a Fargate Instance. This repository also has IAAC for infrastructure required for load balancing the ECS services. 

The infrastructure includes
- VPC
- subnets
- security groups
- internet gateways
- application load balancer
- listeners and target groups

# What is browserless
browserless is a web-service that allows for remote clients to connect, drive, and execute headless work; all inside of docker. It offers first-class integrations for puppeteer, playwright, selenium's webdriver, and a slew of handy REST APIs for doing more common work. On top of all that it takes care of other common issues such as missing system-fonts, missing external libraries, and performance improvements. We even handle edge-cases like downloading files, managing sessions, and have a fully-fledged documentation site.

If you've been struggling to get Chrome up and running docker, or scaling out your headless workloads, then browserless was built for you.

## How it works
browserless listens for both incoming websocket requests, generally issued by most libraries, as well as pre-build REST APIs to do common functions (PDF generation, images and so on). When a websocket connects to browserless it invokes Chrome and proxies your request into it. Once the session is done then it closes and awaits for more connections. Some libraries use Chrome's HTTP endpoints, like /json to inspect debug-able targets, which browserless also supports.

Your application still runs the script itself (much like a database interaction), which gives you total control over what library you want to choose and when to do upgrades. This is preferable over other solutions as Chrome is still breaking their debugging protocol quite frequently.

### Features

- Supports common web drivers (Playwright, Selenium, and Puppeter)

- Through a remote web driver any client application can proxy requests through headless chrome browser and get the response back

- Hosted in ECS using Fargate Spot instance provider to reduce hosting cost

- Has an auto-scaler to ensure high availability of the service

- Containerized environment that is currently setup to accept 5 concurrent connections in each task (container)

- Has a built-in REST API interface

## Setup local testing environment for Browserless/Chrome

- Run a docker container and pass the set of configuration ([Ref](https://www.browserless.io/docs/docker)) you would like to test
```
docker run -p 3000:3000 -e "MAX_QUEUE_LENGTH=1000" -e "CONNECTION_TIMEOUT=180000" browserless/chrome
```
- Browse in a debugger mode by visiting the following link `http://localhost:3000`
- Fetch a page source through Headless Browser API endpoint `/content` ([Ref](https://chrome.browserless.io/docs/#/Browser%20API/post_content))
```
curl -X POST http://localhost:3000/content \
  -H 'Host: www.tiktok.com' \
  -H 'Content-Type: application/json' \
  -H 'Cache-Control: no-cache' \
  -d '{"url": "https://www.tiktok.com/@disney"}'
```
- Fetch a page source through Headless Browser API configured with a proxy
```
curl -sL -X POST http://localhost:3000/content\?\&--proxy-server\=http://gate.dc.smartproxy.com:20000 \
-H 'Host: www.tiktok.com' \
-H 'Content-Type: application/json' \
-H 'Cache-Control: no-cache' \
-d '{"url": "https://www.tiktok.com/@disney","authenticate": {"username": "pendulum","password": "xxxxxxx"}}' 
```

# Important Configs
The ECS cluster can host multiple services running the same fragate task definition. The number of services to be deployed can be configured from terrafrom variable `ecs_services`

From the application standpoint, traffic from single application load balancer is routed to several several services based on `HOST` header. For Eg to test `ingestion` service

```
curl -X POST http://${ALB_PUBLIC_DNS}:3000/content \
  -H 'Host: ingestion.com' \
  -H 'Content-Type: application/json' \
  -H 'Cache-Control: no-cache' \
  -d '{"url": "https://www.tiktok.com/@disney"}'
```
