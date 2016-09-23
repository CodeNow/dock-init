#!/bin/bash

halter::halt() {
  if [[ "${USE_EXIT}" == "true" ]]; then
    exit 1
  else
    halt
  fi
}
