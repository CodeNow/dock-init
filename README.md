# Dock Init
Scripts and keys needed to initialize docks provisioned via Shiva.

## Introduction
The `dock-init` repository lives on docks and contains the required scripts and
keys needed fully provision and start a dock in a production environment. The
project's primarily used to create new EC2 AMIs that are referenced by
[shiva](https://github.com/CodeNow/astral) during dock provisioning.

This document will cover the basics of what the initialization scripts do, and
how to create a new dock AMI.

## Overview
Docks are instantiated on EC2 by running specialized dock AMIs. These AMIs are
expected to have an `/opt/runnable` path containing all required dock service
repositories along with `dock-init`.

The dock-init scripts are run in response to the provisioning of a new dock via
[shiva](https://github.com/CodeNow/astral):

![Shiva Interaction](https://docs.google.com/drawings/d/1bpHidufswuNd7cNkHvm9jIUs-o9P9XWmag5meeRaMkg/pub?w=708&h=228)

First, a `cluster-instance-provision` event is picked up by a shiva worker
server. Shiva then selects the appropriate dock AMI, and constructs a special
[User Data Script](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
that sets the correct environment variables (`/opt/runnable/env`), and host tags
(`/opt/runnable/host_tags`) for the dock and finally executes the `init.sh` script.

## Logs and Debugging
The logs for the dock init scripts can be found on a dock at the following location:

* `/var/log/user-script-dock-init.log.log`

This should be the first place to look if a dock was provisioned but did not
register itself with the rest of the system correctly. Also pay careful attention
to the version numbers for each of the projects when they are pulled.

## Project Layout

### Source

The project's main script is `init.sh`. This performs the following actions:

1. Connect to consul
2. Check the version of dock-init itself (via consul)
3. If needed, perform a pull to the correct version of dock-init
4. Execute the `dock::init` method defined in `lib/dock.sh`

The rest of the implementation for the project lives in the `lib/` directory.
For the most part the filenames have been chosen to give as much context as
possible to make the project easy to navigate.

### Consul Resources
Dock-init uses consul and the wonderful `consul-template` utility to generate
service upstart scripts via values found in consul. These templates and other
resources associated with consul live in the `consul-resources/` directory.

### Deploy Keys
Each of the services lives on the dock as git repository. When the `init.sh`
script fetches all repository information for a service it uses one or more
of the deploy keys given in the `key/` directory.

NOTE: On an actual dock the private keys require access rights of at least 600.
Use the `util/lock-keys.sh` script to ensure that all private keys are, well,
locked down.

### Development Utilities
The project also comes equipped with a slew of development utility scripts under
the `util/` directory. These scripts make it easy to test dock-init on an ec2
instance, pull specific versions of the library, and perform other tasks.


## Modifying an Existing AMI
This is the easy way to build a new AMI for use by shiva. To do so find the
id of the AMI used by shiva (`configs/.env.production[-beta]`) and spin up a
new instance with that AMI in AWS (do not provide a user-data script).

The resulting instance will be a perfect snapshot of the last AMI that was built.
You can then modify it how you wish, and create a new AMI from the running instance.

## Testing changes
1. log into base dock ``` ssh 10.20.1.33 ```
2. cd to dock-init utils ``` cd /opt/runnable/dock-init ```
3. checkout your branch ``` sudo ./util/checkout.sh <your_branch> ```
4. pull your branch ``` sudo ./util/pull.sh <your_branch> ```
5. find `beta-example` on [amazon ec2 console](https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:search=beta-example;sort=desc:role)
6. right click and `beta-example` go to image -> create image
7. use these settings
  * Image name = beta-build-run-dock-<your_branch>
  * Image description = <something useful>
  * Change all volumes to SSD
  * click create image and not ami id
8. create branch in [astral/shiva](https://github.com/CodeNow/astral) with the same name as <your_branch>
9. deploy your branch of astral/shiva to beta
10. spin up new docks using helper scripts on `beta-services` in folder `~/ryan`
11. ensure the dock comes up and you can run/build on them

## Building an AMI From Scratch (WIP)
NOTE: we should turn this into ansible script so we can auto generate AMIs.

1. Create an EC2 Instance (of any type) with the following EBS Volumes
  * xvdb (1000 GB)
  * xvdc (50 GB)
  * xvdd (50 GB)
2. Mount the EBS volumes to the following root folders:
  * `/docker` -> xvdb
  * `/git-cache` -> xvdc
  * `/layer-cache` -> xvdd
3. Install docker 1.6.2, and weave 0.11.1
4. Place the TLS certificate files in `/etc/ssl/docker`:
  * `ca-key.pem`
  * `ca.pem`
5. Download the following repositories to `/opt/runnable`:
  * `/opt/runnable/dock-init`
  * `/opt/runnable/docker-listener`
  * `/opt/runnable/filibuster`
  * `/opt/runnable/krain`
  * `/opt/runnable/sauron`
6. Place the service upstart scripts:
  * `/etc/init/docker-listener.conf`
  * `/etc/init/filibuster.conf`
  * `/etc/init/krain.conf`
  * `/etc/init/sauron.conf`
7. Place the upstart override "manual" files to prevent start on boot:
  * `echo "manual" > /etc/init/docker-listener.override`
  * `echo "manual" > /etc/init/filibuster.override`
  * `echo "manual" > /etc/init/krain.override`
  * `echo "manual" > /etc/init/sauron.override`
8. Save an AMI of the Instance via the [AWS Web Admin Panel](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
