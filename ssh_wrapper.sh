#!/bin/sh
exec /usr/bin/ssh -i /home/runner/.ssh/id_rsa "$@"
