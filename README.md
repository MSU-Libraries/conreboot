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

## The Config File
Each host machine the conditional reboot script will be run on must have a config file setup
or the script will do nothing and exit.  

The script should be placed at: `/etc/coreboot.cfg`  

The script has following settings:  

`REBOOT_TIMES` (required)  
This sets the allowed times when a reboot can occur. Format is a comma-delimited list
of time ranges. Times are in the format such as `3am-7:30am` or `11:30pm-2:30am`  
```
# Examples:
REBOOT_TIMES=12pm-6am
REBOOT_TIMES=10pm-1am,4:30am-6am
```

`PREVENT_PROCESSES`  
Prevent reboot if the listed process(es) are running. Multiple processes may be specified as part
of a comma-delimited list. This can list just the process or the process with flags.  
```
# Examples:
PREVENT_PROCESSES=rsync,mysqldump
PREVENT_PROCESSES=mycommand --with-fl -ags
```

`PREVENT_ACTIVE_USER_SECONDS`  
TODO  

`PREVENT_IF_SCRIPT_FAILS`  
TODO  

`SHUTDOWN_TIME`  
TODO  

`DELAY_UNTIL_OKAY`  
TODO  

`PRE_SHUTDOWN_COMMAND`  
TODO  


## Ansible: Send Reboot Request (includes setup steps)
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

## Ansible: Setup Reboot Only (does not send reboot request)
This command will:  
 - Setup/update all requirements on the target hosts (e.g script and service)
 - NOT trigger any reboot requests
 - NOT setup or modify any configuration files on target hosts
```
# Send reboot request to ALL hosts
ansible-playbook playbook-setup-only.yml
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

## Ansible: Copy a coreboot.cfg to host machines
This command will:  
 - Copy a local file called `coreboot.cfg` to target hosts at `/etc/coreboot.cfg`
 - Require you first create a local `coreboot.cfg` file
 - Overwrite the `/etc/coreboot.cfg` on target hosts if they already exist
```
# Copy a local coreboot.cfg file to target machines
ansible-playbook playbook-send-coreboot-cfg.yml -l "host5.example.edu,host6.example.edu"
```

