Conditional Reboot
==================
Triggers a reboot on a Linux server when preset conditions are met. The primary condition is that the server indicates that it needs to be rebooted. Other conditions are defined in a config file on the server.  

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
 - update-notifier (debian / ubnutu family of Linux)
 - yum-utils/dnf-utils (rhel or centos family of Linux)

The `coreboot` service will reboot the server via a `shutdown -r` command when the server indicates that it requires a restart (due to package/kernel upgrades) or if the administrator issues a manually scheduled reboot to occur. In addtion to this, the `coreboot` service checks the config file to ensure those conditions also match, for example at what time is it safe to reboot.  

## The Command
The `coreboot` command is central to the service. It has the following flags:  
* `--help/-h` Display help about the flags.
* `--status/-s` Display status of coreboot service, if any reboot is pending, and status of each condition that must happen before a reboot could happen.
* `--manual/-m` Schedule a manual coreboot to happen as soon as all conditions are safe, even if the server does not indicate the need to reboot.
* `--cancel/-c` Cancel a scheduled manual coreboot.
* `--daemon/-d` Start as a coreboot daemon; used by the systemd service unit.

## The Config File: /etc/coreboot.cfg
Each host machine the conditional reboot script will be run on must have a config file setup
or the script will do nothing and exit.  

The config should be placed at: `/etc/coreboot.cfg` (see included `coreboot.cfg.example` file)  

The config has following settings:  
 * [`REBOOT_TIMES`](#reboot_times)
 * [`PREVENT_PROCESSES`](#prevent_processes)
 * [`PREVENT_ACTIVE_USER_MINUTES`](#prevent_active_user_minutes)
 * [`PREVENT_IF_SCRIPT_FAILS`](#prevent_if_script-fails)
 * [`SHUTDOWN_TIME`](#shutdown_time)
 * [`PRE_SHUTDOWN_COMMAND`](#pre_shutdown_command)

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

## Locally: Manually schedule an conditional reboot
This command will:  
 - Schedule an conditional reboot (i.e. `coreboot`) on the localhost
```
# Attempt to reboot as soon as possible, only delaying until reboot is safe to happen
coreboot --manual
```

## Locally: Cancel a Scheduled Reboot
These commands will:  
 - Stop a scheduled `coreboot` service reboot on the local host
 - Cancel any scheduled `shutdown` command on the local host
```
# Unschedule a scheduled conditional reboot
coreboot --cancel
# Cancel an already issued shutdown command
shutdown -c
```

