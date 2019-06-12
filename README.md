# Angular build

**NB** I KNOW this is naïve shit, and it is on purpose bc. you know I hate this Docker shit but I am forced to do it. 
If you like this pretentious shit, feel free to create a PR and fix it up. 

A simple container for building Angular 6 projects,


Contains the stuff that I think that I need.

* yarn 
* Headless chrome
* node carbon
* shellcheck
* jq
* terraform
* Sonar Scanner

I am forced to do this kind of stuff since every CI/CD system requires a Docker container.

## Scripts

The `codebuild.sh` script exports a number of utility functions:

* create_version_file - Is Angular specific and creates a version file in `./src/assets`
* *export_build_info* - Exports a number of variables to be used as version data.

## Building

We basically rely on Docker to build it, to test build manually
    
`docker build --tag angular-build:local .`

## Running

### Windoze

`winpty docker run --rm -it rexsuecia/angular-build:devleop bin/bash`

## Real OS:es
`docker run --rm -it rexsuecia/angular-build:develop bin/bash`
