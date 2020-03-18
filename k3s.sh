#!/bin/bash

until curl --output /dev/null --silent --head --fail https://www.google.com; do
    printf '.'
    sleep 5
done

curl -sfL https://get.k3s.io | sh - > ~/k3s.log 2>&1
echo "completed" >> ~/k3s.log
