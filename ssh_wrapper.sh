#!/bin/sh
exec /usr/bin/ssh -i $HOME/.ssh/id_rsa "$@"
