Conditional Reboot
==================
Ability to triggers a reboot if preset conditions are met.  

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

## Ansible: Send Reboot Request (includes setup steps)
This command will:  
 - Setup/update all requirements on the target hosts (e.g script and service)
 - Send a request to do a conditional reboot (i.e. `coreboot`) to the target hosts
 - NOT setup or modify any configuration files on target hosts
```
# Send reboot request to ALL hosts
ansible-playbook playbook-reboot.yml

# Send reboot only to specific groups
ansible-playbook playbook-reboot -l "devel_test,stage"

# Send reboot only to specific hosts
ansible-playbook playbook-reboot -l "host2.example.edu,host7.example.edu"
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



