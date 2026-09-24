#!/bin/bash

set -eux

dnf install -y nodejs npm git
npm install -g pm2

echo "User data completed" > /home/ec2-user/user-data-complete.txt