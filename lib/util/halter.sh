#!/bin/bash

halter::halt() {
  if [[ "${DONT_HALT}" == "" ]]; then
    halt
  fi
}
