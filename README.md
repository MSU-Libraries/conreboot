conreboot - Conditional Rebooter
==================
Triggers a reboot on a Linux system when preset conditions are met. The primary condition is that the server indicates that it needs to be rebooted. Other conditions are defined in a config file on the server.  

**Requirements:**  
 - Bash
 - systemd
 - awk
 - grep
 - pgrep
 - procps
 - findutils
 - coreutils
 - update-notifier (Debian/Ubnutu)
 - yum-utils/dnf-utils (RHEL/Rocky)

The `conreboot` service will reboot the server via a `shutdown -r` command when the server indicates that it requires a restart (due to package/kernel upgrades) or if the administrator issues a manually scheduled reboot to occur. In addtion to this, the `conreboot` service checks the config file to ensure those conditions also match, for example at what time is it safe to reboot.  

## The Command
The `conreboot` command is central to the service. It has the following flags:  
* `--help/-h` Display help about the flags.
* `--status/-s` Display status of conreboot service, if any reboot is pending, and status of each condition that must happen before a reboot could happen.
* `--manual/-m` Schedule a manual conreboot to happen as soon as all conditions are safe, even if the server does not indicate the need to reboot.
* `--cancel/-c` Cancel a scheduled manual conreboot.
* `--daemon/-d` Start as a conreboot daemon; used by the systemd service unit.

## The Config File: /etc/conreboot.cfg
Each host machine the conditional reboot script will be run on must have a config file setup
or the script will do nothing and exit.  

The config should be placed at: `/etc/conreboot.cfg` (see the `TODO/PATH/conreboot.cfg.example`).  

The config has following settings:  
 * [`REBOOT_TIMES`](#reboot_times)
 * [`SHUTDOWN_TIME`](#shutdown_time)
 * [`PREVENT_ACTIVE_USER_MINUTES`](#prevent_active_user_minutes)
 * [`PREVENT_PROCESSES`](#prevent_processes) (multiples allowed)
 * [`PREVENT_IF_SCRIPT_FAILS`](#prevent_if_script-fails) (multiples allowed)
 * [`PRE_SHUTDOWN_COMMAND`](#pre_shutdown_command) (multiples allowed)

### REBOOT_TIMES
Default value: `never`  
This sets the allowed times when a reboot can occur. Format is a comma-delimited list
of time ranges. Times are in the format such as `3am-7:30am` or `11:30pm-2:30am`  
When set to `never`, `conreboot` will not be trigger reboots and will exit with code 0.  
```
# Examples:
REBOOT_TIMES=12pm-6am
REBOOT_TIMES=10pm-1am,4:30am-6am
REBOOT_TIMES=never
```

### SHUTDOWN_TIME
Default: `+1`  
Sets the TIME argument to the `shutdown` command. Default is 1 minute warning before shutdown commences.
Setting to `+0` or `now` will result in immediate shutdown once it is determined to be okay to reboot.  
```
SHUTDOWN_TIME=now
SHUTDOWN_TIME=+5
```

### PREVENT_ACTIVE_USER_MINUTES
Default: `60`  
Prevent reboot if there are active users logged in, where an active user is those who have terminal
activity with the given number of minutes. Set to 0 to allow rebooting while users are active.  
Note that this does not count X11 sessions.  
```
PREVENT_ACTIVE_USER_MINUTES=120
PREVENT_ACTIVE_USER_MINUTES=0
```

### PREVENT_PROCESSES
Default: nothing  
Prevent reboot if the listed process(es) are running. Multiple processes may be specified as part
of a comma-delimited list. This can list just the process or the process with flags.  
```
# Examples:
PREVENT_PROCESSES=rsync,mysqldump
PREVENT_PROCESSES=mycommand --with-fl -ags
```

### PREVENT_IF_SCRIPT_FAILS
Default: nothing  
Prevent reboot is the given script or Bash shell command returns anything other than 0. Will do nothing if
value is empty.  
Note that this command should be able to be executed quickly, and repeatedly, as the conditional reboot may
continually run this command every minute while waiting to reboot.  
```
PREVENT_IF_SCRIPT_FAILS="! [[ -f /tmp/my_service.lock ]]"
PREVENT_IF_SCRIPT_FAILS="/usr/local/bin/safe_to_reboot.sh"
```

### PRE_SHUTDOWN_COMMAND
Default: nothing  
When set, this script or Bash shell command will run just prior to the `shutdown` command. The `shutdown`
command will commence regardess of the exit code of this command.  
```
PRE_SHUTDOWN_COMMAND="killall -9 troublesome_processes"
PRE_SHUTDOWN_COMMAND="/usr/local/bin/send_notifications"
```
