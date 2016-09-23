#!/bin/bash

halter::halt() {
  if [[ "${HALT}" == "true" ]]; then
    halt
  else
    exit 1
  fi
}
