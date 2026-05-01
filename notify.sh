#!/bin/bash
curl -s -H "Priority: default" -H "Tags: robot" -d "$1" ntfy.sh/aios
