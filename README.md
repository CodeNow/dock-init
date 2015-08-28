# Dock Init
Scripts and keys needed to initialize docks provisioned via Shiva.

## Introduction
The `dock-init` repository lives on docks and contains the required scripts and
keys needed fully provision and start a dock in a production environment. The
project's primarily used to create new EC2 AMIs that are referenced by
[shiva](https://github.com/CodeNow/shiva) during dock provisioning.

This document will cover the basics of what the initialization scripts do, and
how to create a new dock AMI.

## Overview
Docks are instantiated on EC2 by running specialized dock AMIs. These AMIs are
expected to have an `/opt/runnable` path containing all required dock service
repositories along with `dock-init`.

The dock-init scripts are run in response to the provisioning of a new dock via
[shiva](https://github.com/CodeNow/shiva):

![Shiva Interaction](https://docs.google.com/drawings/d/1bpHidufswuNd7cNkHvm9jIUs-o9P9XWmag5meeRaMkg/pub?w=708&h=228)

First, a `cluster-instance-provision` event is picked up by a shiva worker
server. Shiva then selects the appropriate dock AMI, and constructs a special
[User Data Script](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
that sets the correct environment variables (`/opt/runnable/env`), and host tags
(`/opt/runnable/host_tags`) for the dock and finally executes the `init.sh` script.

## Logs and Debugging
The logs for the dock init scripts can be found on a dock at the following location:

* `/var/log/dock-init.log`

This should be the first place to look if a dock was provisioned but did not
register itself with the rest of the system correctly. Also pay careful attention
to the version numbers for each of the projects when they are pulled. Finally make
sure the correct host tags are set in `/opt/runnable/host_tags`.

## Scripts

### init.sh
The `init.sh` script is responsible for robustly handling the initialization of
a dock. Since there are multiple services that must be updated and restarted it
uses an exponential back-off approach when attempting to initialize the dock.

The script is executed by the EC2 instance's "user-data" script which is set by
[shiva](https://github.com/CodeNow/shiva) during provisioning.

### upstart.sh
The `upstart.sh` script is called by `init.sh` and is responsible for updating
the required services and images to the preferred versions (as set by shivas
user-data script), pulling the required images (image-builder), and restarting
all of the docks core services.

The script updates and restarts the services in the following order:

1. [filibuster](https://github.com/Runnable/Filibuster)
2. [krain](https://github.com/codenow/krain)
3. [sauron](https://github.com/codenow/sauron)
4. [docker-listener](https://github.com/codenow/docker-listener)

Once [docker-listener](https://github.com/codenow/docker-listener) has been
restarted the dock will register itself with
[mavis](https://github.com/codenow/mavis) and will be able to handle build and
run tasks.

### cert.sh
The `cert.sh` script is responsible for generating a new TLS host certificate
for docker. It expects the AMI is preloaded with the following files:

* `/etc/ssl/docker/ca.pem`
* `/etc/ssl/docker/ca-key.pem`

The script generates the needed certificate-key pair for the docker host (also
located at `/etc/ssl/docker`) and removes `/etc/ssl/docker/ca-key.pem` from the
host.

### docker-listener.conf
This is a modified version of the Ubuntu upstart configuration for the
docker-listener service. Our infrastructure requires that each dock report a
set of tags on startup. These tags are used to route build and run events to
customer specific docks. The `docker-listener.conf` has been modified to read
the host tags from a special file that is written by shiva's `user-data` script
before restarting the service.

## Deploy Keys
Each of the services lives on the dock as git repository. When the `upstart.sh`
script fetches all repository information for a service it uses one or more
of the deploy keys given in the `key/` directory.

NOTE: On an actual dock the private keys require access rights of at least 600.
Use the `util/lock-keys.sh` script to ensure that all private keys are, well,
locked down.

## Modifying an Existing AMI
This is the easy way to build a new AMI for use by shiva. To do so find the
id of the AMI used by shiva (`configs/.env.production[-beta]`) and spin up a
new instance with that AMI in AWS (do not provide a user-data script).

The resulting instance will be a perfect snapshot of the last AMI that was built.
You can then modify it how you wish, and create a new AMI from the running instance.

## Building an AMI From Scratch (WIP)

NOTE: Anand has a partial script for creating a new dock but it is missing some
key features. We will need to update his script to include the new changes and
merge the script into [devops-scripts](https://github.com/Codenow/devops-scripts)
master.

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
