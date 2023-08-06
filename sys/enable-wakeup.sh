#!/bin/bash

set -euo pipefail


# echo enabled > /sys/bus/usb/devices/1-10/power/wakeup
# echo enabled > /sys/bus/usb/devices/1-4.1/power/wakeup
# echo enabled > /sys/bus/usb/devices/1-4/power/wakeup
# echo enabled > /sys/bus/usb/devices/1-6/power/wakeup
# echo enabled > /sys/bus/usb/devices/usb1/power/wakeup
# echo enabled > /sys/bus/usb/devices/usb2/power/wakeup

echo enabled > /sys/bus/usb/devices/1-10/power/wakeup
echo enabled > /sys/bus/usb/devices/1-1.2/power/wakeup
echo enabled > /sys/bus/usb/devices/1-1.3/power/wakeup
echo enabled > /sys/bus/usb/devices/1-1/power/wakeup
echo enabled > /sys/bus/usb/devices/1-4.1/power/wakeup
echo enabled > /sys/bus/usb/devices/1-4/power/wakeup
echo enabled > /sys/bus/usb/devices/1-6/power/wakeup
echo enabled > /sys/bus/usb/devices/2-3/power/wakeup
echo enabled > /sys/bus/usb/devices/usb1/power/wakeup
echo enabled > /sys/bus/usb/devices/usb2/power/wakeup

