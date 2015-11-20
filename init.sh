#!/bin/bash

# Entry-point script for dock initialization. Simply includes the `lib/dock.sh`
# library and calls the master initialization function.
# @author Ryan Sandor Richards

source ./lib/dock.sh
dock::init
