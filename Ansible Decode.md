**Inventory File (blue-fw.yaml) - Rocky Section Annotated**

```yaml
all:
```
The top-level key in the yml inventory file. Everything else in the file is nested under this.

```yaml
  children:
```
Means that what follows are groups of hosts rather than individual hosts. Groups let you target specific sets of machines in a playbook.

```yaml
    rocky:
```
The name of this group. When the playbook says `hosts: rocky`, Ansible runs against everything listed under this group.

```yaml
      hosts:
```
Everything nested under this is an individual host that belongs to the rocky group.

```yaml
        rocky-1:
```
The name Ansible uses to refer to this specific host. This is what shows up in the output when the playbook runs.

```yaml
          ansible_host: 10.0.5.11
```
The actual IP Ansible connects to. Without this, Ansible would try to resolve `rocky-1` as a DNS hostname which wouldn't work in this environment.

```yaml
          ansible_user: deployer
```
The SSH user Ansible logs in as when it connects to the host.

```yaml
          ansible_ssh_private_key_file: ~/.ssh/deployer
```
The path to the private key Ansible uses to authenticate over SSH. This matches the public key that was pushed to the VM with `ssh-copy-id`.

```yaml
          ansible_become_password: "*********"
```
The sudo password Ansible uses when a task needs privilege escalation via `become: yes`.

```yaml
          static_ip: "10.0.5.10"
```
A custom variable I defined for this host. Not a built-in Ansible variable -- it just gets referenced in the playbook wherever `{{ static_ip }}` shows up.

```yaml
          hostname: "rocky-1"
```
Another custom variable. Gets passed into the playbook and used in the hostname task wherever `{{ hostname }}` appears.

---

**Playbook File (post-playbook.yml) - Rocky Annotated**

```yaml
---
```
Standard YAML document start marker. Just tells the parser this is the beginning of a YAML file.

```yaml
- name: Post provision Rocky servers
```
A label for this play. Shows up in the terminal output when the playbook runs so you know what is happening.

```yaml
  hosts: rocky
```
Tells Ansible to run this play against all hosts in the `rocky` group defined in the inventory file.

```yaml
  tasks:
```
Everything listed under here is a task that Ansible will execute on the target hosts in order.

```yaml
    - name: Add deployer public key
```
A label for this specific task. Shows up next to the ok/changed/failed status in the output.

```yaml
      authorized_key:
```
The Ansible module being used here. The `authorized_key` module handles adding or removing SSH keys from a user's `authorized_keys` file on the remote host.

```yaml
        user: deployer
```
Tells the module which user's `authorized_keys` file to write to.

```yaml
        state: present
```
Tells the module to make sure the key exists. If this was set to `absent` it would remove the key instead.

```yaml
        key: "{{ lookup('file', '~/.ssh/deployer.pub') }}"
```
The public key to add. The `lookup('file', ...)` reads the contents of `deployer.pub` from the control node and passes it in as the key value.

```yaml
    - name: Create sudo entry for deployer
      become: yes
```
`become: yes` tells Ansible to run this task as root. Needed here because writing to `/etc/sudoers.d/` requires root access.

```yaml
      copy:
```
The `copy` module writes a file to the remote host. In this case it is used to write the sudoers drop-in file from inline content instead of copying a file from disk.

```yaml
        content: "deployer ALL=(ALL) NOPASSWD: ALL\n"
```
The actual content written to the file. This sudoers rule lets the deployer user run any command as root without being prompted for a password. The `\n` at the end adds a newline which sudoers requires to parse the file correctly.

```yaml
        dest: /etc/sudoers.d/deployer
```
Where the file gets written on the remote host. Files dropped in `/etc/sudoers.d/` get automatically included by the main sudoers config.

```yaml
        mode: '0440'
```
Sets the file permissions. `0440` means read-only for root and the group, no permissions for anyone else. This is the standard permission for sudoers files.

```yaml
    - name: Set hostname
      become: yes
      hostname:
```
The `hostname` module sets the system hostname on the remote host. Requires `become: yes` since changing the hostname is a root-level operation.

```yaml
        name: "{{ hostname }}"
```
Passes in the hostname value from the inventory variable defined for each host.

```yaml
    - name: Set static IP
      become: yes
      shell:
```
The `shell` module runs a raw shell command on the remote host. Used here because there is no dedicated Ansible module for nmcli that fit this use case cleanly.

```yaml
        cmd: nmcli con mod ens34 ipv4.addresses {{ static_ip }}/24 ipv4.gateway 10.0.5.2 ipv4.method manual
```
The actual nmcli command that sets the static IP, subnet mask, gateway, and switches the interface from DHCP to manual. Uses the `{{ static_ip }}` variable from the inventory.

```yaml
    - name: Bring connection up
      become: yes
      shell:
        cmd: nmcli con up ens34
```
Brings the network interface back up after the configuration change so the new static IP takes effect without needing a reboot.
