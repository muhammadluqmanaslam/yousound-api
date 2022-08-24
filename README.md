# Yousound

## Deployment Overview

- Builds and Deployments are done via CircleCI when one or more branches match the requirements located at .circleci/config.yml line 5

- CircleCI is responsible for:

1. Define the environment we are deploying to based on teh branch being pushed. Refer to .circleci/config.yml line 23 "PREPARE ENVIRONMENT VARIABLES"

2. Installing the AWS CLI to enable the deployment to AWS Beanstalk. Refer to .circleci/config.yml line 38 "INSTALL DEPLOYMENT DEPENDENCIES"

3. Restore gem cache if no changes were done to GemFile.lock . Refer to .circleci/config.yml line 54 "restore_cache". If a cache is an issue, you can edit the CirclCI project settings and update the cache key to a different random value

4. Installing the application dependencies . Refer to .circleci/config.yml line 61 "install dependencies" . This is related to whether there is a cache available or not.

5. Update CircleCI cache with the latest bundle files (assuming there not fetch from cache). Refer to .circleci/config.yml line 66 "save_cache"

6. Prepare the files for deployment by downloading the env file from an AWS S3 bucket and updating the Dockerrun.aws.json with the values to be passed as env variables to the docker container. Refer to .circleci/config.yml line 72 "PREPARE FILES FOR DEPLOYMENT"

7. Deploying the application to AWS Beanstalk. Refer to .circleci/config.yml line 153 "DEPLOY TO EB"

## Docker Images Overview

- For the deployment, a based docker image containing the Ruby installation and webservers is used. If thats required to be udpated, you can push changes to the repo https://github.com/yousound/api-docker . This repo contains two main branches:

1. Master. It contains the files used to build the base docker images for production deploys.
2. Integration. It contains the file sused to build the based cocker image for Integration deploys.

If an update is required, its suggested that you push changes to integration first, test and then issue a PR rquest to Master. Once any of the branches is updated, CircleCI will trigger the deployment and tag the images as "latest".

## AWS Beanstalk Overview

- API is deployed to an AWS Beanstalk Multi Docker Environment. Both production and integration are located in the N.Virginia region account id 731521589805 .

- While the environments are setup in the same account (to save costs), they use distinct VPC's to logically separate the resources and add some level of security.

- Environemnt variables are located on a S3 bucket and downloaded during the CircleCI run. The bucket is located in the N.Virginia region and is called "ys-circleci" . If changes are required to teh env vars, a new re-deploy from circleCI needs to be done so it can fetch the updated values and deploy to the server.

- EC2 resources are managed by spot.io . This is a third party tool to help allocate spot instances to the Beanstalk environment and eventually save costs. While Beanstalk does offer spot options, spot.io is more intelligent in defining the correct instances that has a higher chance to be up and running for longer. Note that changes to the AWS Beanstalk env regarding capacity, instance types, keys, etc, are not applied and should be managed by the spot.io interface.

- WebServer configurations can be setup in the base docker image. Reference https://github.com/yousound/api-docker/blob/integration/.circleci/nginx/default

- The API domain is pointed to a cloudfront distribution that then points to the application Load Balancer. This is only valid for the API. The frontend domains points directly to the Beanstalk LB.

## Debuging the application

- There are two ways you can debug with the deployments to AWS:

1. By using Papertrail and watching the logs per environment. The main log files are access.log which list any GET/POST requests to the webserver. Error.log that shows any upstream (puma) error and setup.log that describes the initialization commands by supervisorD in initialiazing the apps, sidekiq and other services.

- The list of all files that are tracked and streamed to papertrail can be found here https://github.com/yousound/api-docker/blob/integration/.circleci/log_files.yml

2. By SSH directly to the server and looking at the logs manually. To do that, you have to SSH to bastion server, then ssh to the specific environment. Once insice, you can the ssh to the specific docker container.

- Note that the ssh keys are located in the bastion server /home/ec2-user path of that specific bastion environment.

- Once inside the container, you can refer to the /var/log/supervisor/setup.log for the application init logs and you can refer to /home/ubuntu/yousound/shared/log/puma_access.log or /home/ubuntu/yousound/shared/log/puma_error.log or the nginx errors and access logs as well.

## Install

Things you may want to cover:

- Ruby version
  2.4.1

- Development
  git clone git@github.com:yousound/api.git
  git branch staging
  git fetch

  install rbenv or rvm
  set ruby version 2.4.1
  bundle install

  install elasticsearch ( only for local, we use AWS Elasticsearch on server )
  RAKE_ENV=development RAILS_ENV=development elasticsearch
  rake searchkick:reindex CLASS=User
  rake searchkick:reindex CLASS=Album

  cap development staging

- Connect to Server
  chmod 400 ../info/ec2-refactor2017.pem
  ssh -i ../info/ec2-refactor2017.pem ubuntu@52.53.50.11
  sudo service nginx status ( check nginx, web-server running )
  sudo /usr/sbin/passenger-memory-stats ( check passenger, web-application-server is running )

## Flow

### order flow

- when user places an order, he puts the card info and creates the `stripe_token` on front-end (desktop/mobile) side
- it calls `items/buy` API with `stripe_token`
- on API side, it gets the amount from the card with `stripe_token` and then divide the amount to merchants and collaborators.

## Data Structure

### shop_item

- price: each item price, item_total_price = price \* quantity
- tax: total tax on item regarding to quantity

## ToDo

- Write API documentation
  - Swagger
### streams

- rename StreamsChannel to StreamViewersChannel
- rename StreamCreatorsChannel to StreamChannel
- require all channel name and data
