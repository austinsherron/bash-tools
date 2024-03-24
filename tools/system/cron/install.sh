# TODO: implement crontab installation script; tasks:
#
#   - [x] mv cron executables to "tools:system/cron/run", or something like that
#   - [ ] create crontab directory w/ crontab files named by user
#   - [ ] implement this script using enhancements to cronctl

ulogger info "deploying system/cron/run module"
deploy -s system/cron run

ulogger info "saving existing crontab for user=\"austin\" to austin.txt.bak"
# TODO: cronctl -u austin --save "${TOOLS_ROOT}/system/cron/crontab/austin.txt.bak"

ulogger info "deploying crontab for user=\"austin\""
# TODO: cronctl -u austin -m --load "${TOOLS_ROOT}/system/cron/crontab/austin.txt"

ulogger info "saving existing crontab for user=\"root\" to root.txt.bak"
# TODO: cronctl -u root --save "${TOOLS_ROOT}/system/cron/crontab/root.txt.bak"

ulogger info "deploying crontab for user=\"root\""
# TODO: cronctl -u root -m --load "${TOOLS_ROOT}/system/cron/crontab/root.txt"

