#!/usr/bin/env bash

sudo mkarchiso -v -r -w /tmp/archiso-tmp -o ~/iso_out ~/kiosk_archiso
sudo chown -R $USER:$USER ~/iso_out
