Conditional Reboot
==================
Ability to trigger a reboot on a Linux server only when preset conditions are met.  

**Requirements:**  
 - Bash
 - systemd
 - Perl
 - awk
 - grep
 - pgrep
 - procps
 - findutils
 - coreutils

## The Config File: /etc/coreboot.cfg
Each host machine the conditional reboot script will be run on must have a config file setup
or the script will do nothing and exit.  

The config should be placed at: `/etc/coreboot.cfg` (see included `coreboot.cfg.example` file)  

The config has following settings:  
 * [`REBOOT_TIMES`](#reboot-times)
 * [`PREVENT_PROCESSES`](#prevent-processes)
 * [`PREVENT_ACTIVE_USER_MINUTES`](#prevent-active-user-minutes)
 * [`PREVENT_IF_SCRIPT_FAILS`](#prevent-if-script-fails)
 * [`SHUTDOWN_TIME`](#shutdown-time)
 * [`DELAY_UNTIL_OKAY`](#delay-until-okay)
 * [`PRE_SHUTDOWN_COMMAND`](#pre-shutdown-command)

### REBOOT_TIMES
Default value: `never`  
This sets the allowed times when a reboot can occur. Format is a comma-delimited list
of time ranges. Times are in the format such as `3am-7:30am` or `11:30pm-2:30am`  
When set to `never`, conditional reboot requests will never be allowed and the `coreboot` will exit with code 0  
```
# Examples:
REBOOT_TIMES=12pm-6am
REBOOT_TIMES=10pm-1am,4:30am-6am
REBOOT_TIMES=never
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

### PREVENT_ACTIVE_USER_MINUTES
Default: `60`  
Prevent reboot if there are active users logged in, where an active user is those who have terminal
activity with the given number of minutes. Set to 0 to allow rebooting while users are active.  
Note that this does not count X11 sessions.  
```
PREVENT_ACTIVE_USER_MINUTES=120
PREVENT_ACTIVE_USER_MINUTES=0
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

### SHUTDOWN_TIME
Default: `+1`  
Sets the TIME argument to the `shutdown` command. Default is 1 minute warning before shutdown commences.
Setting to `+0` or `now` will result in immediate shutdown once it is determined to be okay to reboot.  
```
SHUTDOWN_TIME=now
SHUTDOWN_TIME=+5
```

### DELAY_UNTIL_OKAY
Default: `1`  
Once a conditional reboot request has been scheduled, whether or not to keep checking every minute until
it is safe to reboot. When set to `1`, the `coreboot` service keep checking until it is safe to reboot, then
initiate a reboot. When set to `0`, only one reboot attempt will be performed.  
```
DELAY_UNTIL_OKAY=0
DELAY_UNTIL_OKAY=1
```

### PRE_SHUTDOWN_COMMAND
Default: nothing  
When set, this script or Bash shell command will run just prior to the `shutdown` command. The `shutdown`
command will commence regardess of the exit code of this command.  
```
PRE_SHUTDOWN_COMMAND="killall -9 troublesome_processes"
PRE_SHUTDOWN_COMMAND="/usr/local/bin/send_notifications"
```


## Ansible: Send Reboot Request
This command will:  
 - Setup/update all requirements on the target hosts (e.g script and service)
 - Send a request to do a conditional reboot (i.e. `coreboot`) to the target hosts
 - NOT setup or modify any configuration files on target hosts
```
# Send reboot request to ALL hosts
ansible-playbook playbook-reboot.yml

# Send reboot only to specific groups
ansible-playbook playbook-reboot.yml -l "devel_test,stage"

# Send reboot only to specific hosts
ansible-playbook playbook-reboot.yml -l "host2.example.edu,host7.example.edu"
```

## Ansible: Setup Reboot Script and Service Only
This command will:  
 - Setup/update all requirements on the target hosts (e.g script and service)
 - NOT trigger any reboot requests
 - NOT setup or modify any configuration files on target hosts
```
# Send reboot request to ALL hosts
ansible-playbook playbook-setup-only.yml
```

## Ansible: Cancel a Schedule Reboot
This command will:  
 - Stop a scheduled `coreboot` service reboot on target hosts
 - Cancel any scheduled `shutdown` command on target hosts
```
# Attempt to cancel reboot request to specific hosts
ansible-playbook playbook-cancel-reboot.yml -l "production"
ansible-playbook playbook-cancel-reboot.yml -l "host1.example.edu,host8.example.edu"
```

## Ansible: Copy a coreboot.cfg to host machines
This command will:  
 - Copy a local file called `coreboot.cfg` to target hosts at `/etc/coreboot.cfg`
 - Require you first create a local `coreboot.cfg` file
 - Overwrite the `/etc/coreboot.cfg` on target hosts if they already exist
```
# Copy a local coreboot.cfg file to target machines
ansible-playbook playbook-send-coreboot-cfg.yml -l "host5.example.edu,host6.example.edu"
```

## Locally: Attempt an immediate conditional reboot
This command will:  
 - Attempt a conditional reboot immediately on the local host, or diplay a message if the reboot could not take place
 - Ignore the user session calling the script from being considered an active user
 - NOT schedule a conditional reboot for later, should it not be possible now
```
# Attempt to reboot immediately, if it is safe to do so
coreboot
```

## Locally: Schedule an immediate conditional reboot
This command will:  
 - Schedule an immediate conditional reboot (i.e. `coreboot`) on the localhost
```
# Attempt to reboot immediately, including delaying until reboot is safe to happen, if the config allows that
systemctl start coreboot
```

## Locally: Cancel a Scheduled Reboot
These commands will:  
 - Stop a scheduled `coreboot` service reboot on the local host
 - Cancel any scheduled `shutdown` command on the local host
```
# Unschedule a scheduled conditional reboot
systemctl stop coreboot
# Cancel an already issued shutdown command
shutdown -c
```

