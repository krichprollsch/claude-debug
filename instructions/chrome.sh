#!/bin/sh

rm -fr /tmp/chrome-tmp; mkdir /tmp/chrome-tmp

google-chrome --remote-debugging-address=0.0.0.0 \
    --remote-debugging-port=9223 --window-size=1200,800 --no-first-run \
    --user-data-dir=/tmp/chrome-tmp \
    --headless=new \
    --proxy-server=http://127.0.0.1:3000 --ignore-certificate-errors
