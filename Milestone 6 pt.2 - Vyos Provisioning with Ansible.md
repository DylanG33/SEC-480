# Milestone 6 Part 2 - VyOS Provisioning with Ansible

## Overview

This milestone covers provisioning `blue27-fw` using Ansible and a Jinja2 template to drop a complete VyOS configuration onto a freshly cloned firewall VM. 
The goal was to automate the full config deployment including interface IPs, hostname, gateway, DNS, and a hashed password without manually touching the VyOS CLI.

---

## Steps

### Snapshot before-ansible

Before touching anything, took a snapshot of `blue27-fw` in vCenter called `before-ansible` so there was a clean revert point in case the config deployment broke something.

### Build the Jinja2 template

SSHed into the unconfigured `blue27-fw` and ran `show configure` to get the baseline config structure. Used that as the basis for `templates/config.boot.j2`, swapping in Jinja2 variables for all the blue network specific values.

Template location: `~/SEC-480/ansible/templates/config.boot.j2`

Variables used:
- `{{ wan_ip }}` - eth0 WAN address
- `{{ lan_ip }}` - eth1 LAN address
- `{{ hostname }}` - firewall hostname
- `{{ gateway }}` - default gateway
- `{{ nameserver }}` - DNS server
- `{{ network }}` - allowed network CIDR
- `{{ password_hash }}` - sha512 hashed password

### Write the Ansible inventory

Created a plain text inventory file at `~/SEC-480/ansible/inventory` with `blue27-fw` pointed at its pre-configuration IP `10.0.17.103`, using `vyos` as the SSH user.

### Write the playbook

Created `~/SEC-480/ansible/vyos-blue.yml`:

```yaml
---
- name: Configure blue27-fw VyOS firewall
  hosts: blue27-fw
  gather_facts: false
  vars:
    wan_ip: "10.0.17.200"
    lan_ip: "10.0.5.2"
    hostname: "blue27-fw"
    gateway: "192.168.3.250"
    nameserver: "192.168.4.5"
    network: "10.0.17.0/24"
  vars_prompt:
    - name: new_password
      prompt: "Enter new VyOS password"
      private: yes
  tasks:
    - name: Generate sha512 password hash
      set_fact:
        password_hash: "{{ new_password | password_hash('sha512') }}"
    - name: Copy rendered config.boot to VyOS
      become: yes
      template:
        src: templates/config.boot.j2
        dest: /config/config.boot
    - name: Reboot the firewall
      become: yes
      shell: "sleep 2 && reboot"
```

- `gather_facts: false` - VyOS doesn't support Ansible's fact gathering module so this has to be disabled or the playbook errors out immediately
- `vars` - Static network values for the blue network that get passed into the Jinja2 template at render time
- `vars_prompt / private: yes` - Prompts for a password at runtime and hides the input, keeping credentials out of the playbook file
- `password_hash: "{{ new_password | password_hash('sha512') }}"` - Hashes the plaintext input with sha512 since VyOS stores passwords as hashes in config.boot, not plaintext
- `template: src / dest` - Renders config.boot.j2 with all variables filled in and writes the result directly to `/config/config.boot` on the firewall
- `become: yes` - Required on the template and reboot tasks since writing to `/config/` and rebooting both need root
- `shell: "sleep 2 && reboot"` - The sleep gives Ansible time to exit the SSH session cleanly before the host goes down, avoiding a false connection error

### Run getIP before the playbook

Ran `getIP` on `blue27-fw` from xubuntu-wan before executing the playbook to capture the pre-configuration state for the demo.

### Run the playbook

```bash
cd ~/SEC-480/ansible
ansible-playbook -i inventory vyos-blue.yml
```

Entered the new password at the prompt. Playbook ran clean with `ok=3, changed=2`. The SSH connection dropped after the reboot task which is expected behavior.

### Troubleshooting - CD/DVD boot issue

After the first run the config did not apply. Console access showed the VM was trying to boot from ISO. Fixed this in vCenter by editing the VM settings and unchecking "Connect at power on" for the CD/DVD drive, then reverted to the `before-ansible` snapshot and ran the playbook again.

### Verify after reboot

After the reboot, SSHed into the new IP and confirmed the addresses came up correctly:

- `eth0` - `10.0.17.200/24` (WAN)
- `eth1` - `10.0.5.2/24` (LAN)

Ran `getIP` again for the after screenshot to show in the demo.

### Push to GitHub

```bash
cd ~/SEC-480
git add ansible/vyos-blue.yml ansible/templates/config.boot.j2
git commit -m "Milestone 6.4 - VyOS blue firewall provisioning with Ansible"
git pull origin main --no-rebase
git push
```
