# Dock Init
Scripts and keys needed to initialize docks provisioned via Shiva.

## Introduction
The `dock-init` repository lives on docks and contains the required scripts and
keys needed fully provision and start a dock in a production environment. The
project is primarily create new EC2 AMIs that are used by
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
that sets the correct environment variables for the dock and executes the
`init.sh` script.

## Scripts

### init.sh
The `init.sh` script is responsible for robustly handling the initialization of
a dock. Since there are multiple services that must be updated and restarted it
uses an exponential back-off approach when attempting to initialize the dock.

This script, in particular, is called by the EC2 instance's "user-data" script
which is set by [shiva](https://github.com/CodeNow/shiva) during provisioning.

The results of the initialization script are logged to the following file on the
dock: `/var/log/dock-init.log`.

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

## Building an AMI From Scratch (WIP)

* docker 1.6.2 (bound to /docker on an EBS)
* weave 0.11.1
* `/opt/runnable/dock-init`
* `/opt/runnable/docker-listener` and `/etc/init` (both .conf and .override=manual)
* `/opt/runnable/filibuster` and `/etc/init` (both .conf and .override=manual)
* `/opt/runnable/krain` and `/etc/init` (both .conf and .override=manual)
* `/opt/runnable/sauron` and `/etc/init` (both .conf and .override=manual)
