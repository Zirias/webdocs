% Jailed and kerberized NFS with a samba AD DC
% Felix Palmen <zirias@FreeBSD.org>
% 2024-03-21

You will find a few docs on using kerberized NFS with FreeBSD, and I recommend
you read at least the [KerberizedNFS](https://wiki.freebsd.org/KerberizedNFS)
FreeBSD wiki page for basic information. This document will focus on the
issues specific to using a samba domain controller for kerberos
authentication.

A configuration will be shown how to setup the NFS server in a jail (possibly
together with a samba instance serving the same shares via SMB for Windows
clients, but configuring this samba instance is out of scope).

# 0. Prerequisites

It is assumed you already have a samba domain controller up and running, and
any machines that should access your kerberized NFS shares are joined to that
domain. It is also assumed the clients are already configured to do kerberos
authentication using your samba domain.

Configuration of a samba domain and FreeBSD domain members in general will be
out of scope for this document.

To jail the NFS server itself, you need at least FreeBSD 13.3.

> **Warnings**
>
> - If you have your domain controller in a jail, do **not** use this same
>   jail for serving files (neither with NFS nor with samba)
>
> - If you want to share the files with SMB as well, or access them locally,
>   do **not** enable any "tuning" options like `vfs.nfsd.issue_delegations=1`

> **Note:** All the following assumes your new file server will be named
> `files`, your local DNS domain is `local.example` and your kerberos realm is
> `LOCAL.EXAMPLE`, so replace these values as needed in all the following
> commands and configurations.

# 1. Create a new jail

In this example, we will give the jail a ZFS dataset to manage and share. This
isn't really a requirement, but you must make sure that the jail is running
from its own filesystem and for NFSv4, all the shares should be available from
some common mount point.

First, follow your "normal" procedure to install a new jail with at least
FreeBSD 13.3. It's not described here because there are many possible ways and
also different tools available to manage your jail. The important thing is: It
**must** be a `VNET` jail.

Then, create a ZFS dataset for sharing files, e.g.

~~~{.sh}
$ zfs create zroot/netshares
$ zfs set jailed=on zroot/netshares
~~~

You can now create child datasets for sharing, or move existing datasets with
`zfs rename`.

If you don't have a devfs ruleset to allow the ZFS device in a jail yet,
create one in `/etc/devfs.rules`:

~~~
[devfsrules_jail_zfs=100]
add include $devfsrules_hide_all
add include $devfsrules_unhide_basic
add include $devfsrules_unhide_login
add path 'zfs' unhide
~~~

The name doesn't matter much, and the number should be one that's unused so
far, starting with `100`. Then it's time for the jail configuration, I'll show
here an example what to add in plain `/etc/jail.conf`:

~~~
files {
     vnet = new;
     vnet.interface = epair1b;
     allow.mount;
     allow.mount.zfs;
     allow.nfsd;
     devfs_ruleset = 100;
     enforce_statfs = 1;
     exec.created = "zfs jail files zroot/netshares";
     exec.release = "zfs unjail files zroot/netshares";
}
~~~

Your interface name will most likely differ, also make sure to use the number
of the devfs ruleset you just created.

This assumes you have some common settings for all jails like e.g.

~~~
exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;
mount.fstab = "/var/jail/${name}.fstab";
host.hostname = "${name}.local.example";
allow.noset_hostname;
~~~

> **Tip:** If you want to prioritize file serving on a somewhat busy host, you
> might want to add something like
>
> ~~~
> exec.start = "/usr/bin/nice -n -20 /bin/sh /etc/rc";
> ~~~
>
> to the configuration of this new jail.

Now enter your new jail, install necessary packages (e.g. `samba`) and join it
to the domain. This requires some configuration first, so create
`/etc/krb5.conf` and (when using samba/winbind) `/usr/local/etc/smb4.conf` in
the same way you do on your other domain-joined machines. How exactly to
configure it depends a lot on your environment, therefore this is out of scope
for this document.

Once done, issue some command like `net ads join -UAdministrator` (again
assuming you use samba/winbind).

Then also edit `/etc/nsswitch.conf` and `/etc/pam.d/system` to use account
information and authentication against your domain. Again, what to put there
exactly depends on your environment, e.g. whether you are using `winbind` or
`sssd`.

Make sure everything works by checking some existing domain accounts with the
`id` tool and trying to authenticate locally as some domain user.

Finally, add these settings to your `/etc/rc.conf`:

~~~
zfs_enable="YES"
gssd_enable="YES"
nfs_server_enable="YES"
nfs_server_flags="-t"
nfsv4_server_enable="YES"
nfsv4_server_only="YES"
nfsuserd_enable="YES"
~~~

`zfs_enable` is only required when using a jailed ZFS dataset as recommended
here. `nfs_server_flags` are necessary for a jailed NFS, because otherwise,
the daemon tries to offer UDP, which doesn't work in a jail. You don't really
need the `nfsv4_server_only` setting, but as kerberos only works with v4, it's
pointless for most scenarios to offer NFSv3. Leave it out if you want/need to
share some read-only stuff to clients that can't do NFSv4, but in that case,
you will also need `rpcbind`.

# 2. Create an SPN for your NFS server

The NFS server will need a Service Principal Name to authenticate itself
towards clients. This must be named `nfs/<host>.<domain>`, so in our example
`nfs/files.local.example`.

Log in to your samba domain controller and issue these commands:

~~~{.sh}
$ samba-tool user create nfs-files --random-password
$ samba-tool spn add nfs/files.local.example nfs-files
~~~

If you have some expiration policies enabled, you might also need

~~~{.sh}
$ samba-tool user setexpiry nfs-files --noexpiry
~~~

A dedicated "service account" as shown here isn't strictly necessary, but best
practice.

Then, export keys for your new SPN with

~~~{.sh}
$ samba-tool domain exportkeytab nfs.keytab --principal=nfs/files.local.example
~~~

Transfer the `nfs.keytab` file to your new file server jail and add it to
`/etc/krb5.keytab` there:

~~~{.sh}
$ ktutil copy nfs.keytab /etc/krb5.keytab
~~~

You can verify the contents of your keytab with

~~~{.sh}
$ ktutil list
~~~

It should now contain at least one entry for your new SPN.

> **Warning:** Kerberos keys must be kept secret. Make sure to delete any
> temporary keytab files once the keys were added where they are needed.

> **Tip:** If you ever mess up with your `/etc/krb5.keytab` on a domain
> member, you can restore it by just deleting it and re-joining this machine
> to the domain, which will initialize it with just the keys necessary for the
> machine to work as a domain member.

# 3. Configure your NFS shares

Set a mountpoint for your new `zroot/netshares` jailed dataset:

~~~{.sh}
$ zfs set mountpoint=/usr/local/netshares zroot/netshares
~~~

If you haven't done so yet, create some child dataset for sharing, e.g.

~~~{.sh}
$ zfs create zroot/netshares/stuff
~~~

Now, configure `/etc/exports`, e.g. like this:

~~~
V4: /usr/local/netshares -sec=krb5:krb5i:krb5p

/usr/local/netshares/stuff
~~~

The first line will set the NFS root and only allow kerberos authenticated
access. The second line will share our newly created dataset. You can also use
the `-sec` option on individual shares. Refer to the `exports(5)` man page for
more information.

Reboot your new file server jail, it should now start to serve NFS shares.

# 4. FreeBSD clients, mounting as a user

Any client must run `gssd` and `nfsuserd` as well, so add at least these to
your `/etc/rc.conf`:

~~~
gssd_enable="YES"
nfsuserd_enable="YES"
~~~

and start these services.

Accessing the NFS shares should immediately work from a domain-joined client
for a user in posession of a valid kerberos TGT (ticket-granting ticket). You
can test this on a member machine that has the `vfs.usermount=1` sysctl set
after logging in as a domain user:

~~~{.sh}
$ mkdir mounttest # we need a mountpoint we own ourselves
$ mount -t nfs -o nfsv4,sec=krb5i files:/stuff mounttest
~~~

In case this does **not** work, you'll have to double-check your kerberos
configuration. Start by inspecting the output of `klist`. It *should* contain
a TGT, and after successful access to NFS, also a service ticket for the NFS
server, e.g. like:

~~~
Credentials cache: FILE:/tmp/krb5cc_10000
        Principal: johndoe@LOCAL.EXAMPLE

  Issued                Expires               Principal
Mar 21 08:13:55 2024  Mar 21 18:13:55 2024  krbtgt/LOCAL.EXAMPLE@LOCAL.EXAMPLE
Mar 21 08:13:58 2024  Mar 21 18:13:55 2024  nfs/files.local.example@LOCAL.EXAMPLE
~~~

A correctly working domain client will obtain a TGT on user login. It's
crucial to get this working correctly, as the TGT will also be necessary to
access the share even when you mount it system-wide.

# 5. FreeBSD clients, system-wide mounts

For system-wide mounts, we need a different way to obtain a kerberos TGT: Use
a key from the local keytab as the "host based initiator". The first thing
necessary for this is running `gssd` with the `-h` flag to support this, so
add the following to your `/etc/rc.conf` (and then restart gssd):

~~~
gssd_flags="-h"
~~~

On a samba domain member, we will have keys for the AD machine account and for
a "host" SPN available, e.g. like this on a machine named "client":

~~~
$ ktutil list
FILE:/etc/krb5.keytab:

Vno  Type                     Principal                                Aliases
 10  aes256-cts-hmac-sha1-96  host/client.local.example@LOCAL.EXAMPLE  
 10  aes256-cts-hmac-sha1-96  host/CLIENT@LOCAL.EXAMPLE                    
 10  aes128-cts-hmac-sha1-96  host/client.local.example@LOCAL.EXAMPLE  
 10  aes128-cts-hmac-sha1-96  host/CLIENT@LOCAL.EXAMPLE                    
 10  arcfour-hmac-md5         host/client.local.example@LOCAL.EXAMPLE  
 10  arcfour-hmac-md5         host/CLIENT@LOCAL.EXAMPLE                    
 10  aes256-cts-hmac-sha1-96  CLIENT$@LOCAL.EXAMPLE                        
 10  aes128-cts-hmac-sha1-96  CLIENT$@LOCAL.EXAMPLE                        
 10  arcfour-hmac-md5         CLIENT$@LOCAL.EXAMPLE                        
~~~

A Linux NFS client would automatically try the AD machine account (`CLIENT$`)
which always works fine. Unfortunately, FreeBSD's `mount_nfs` insists on using
an SPN for the purpose. There's the `gssname` mount option which automatically
gets `/<host>.<domain>` appended, so setting it to `host` here will result in
`host/client.local.example`.

As the `host` SPN identifies the machine, it makes sense to use it, so we'll
add something like this to `/etc/fstab`:

~~~
files:/stuff    /mnt/stuff  nfs nfsv4,sec=krb5i,gssname=host,late   0   0
~~~

Trying `mount /mnt/stuff` now will give you a "permission denied" error,
although it *should* work. The reason, as far as I can tell, is that in a
samba domain, an account isn't found by a service principal name attached to
it, only by its `sAMAccountName` or `userPrincipalName` properties.

> **Warning:** I consider the following workaround for this problem a hack.
> There must be a different way to solve it (and I read about a way
> configuring kerberos "libdefaults" differently, but this seems to only work
> with MIT krb5). If you know a way that works reliably with a FreeBSD client
> using heimdal kerberos from base, please let me know, so I can update this
> document.

What we can do about it is to edit the machine account for every client on the
domain controller. These machine accounts by default don't have a
`userPrincipalName`, so we can add one. So do the following on your domain
controller for the client named `client`:

~~~{.sh}
$ samba-tool computer edit client
~~~

which will open your editor (from the `EDITOR` environment variable) with all
the properties of the computer account, looking something like this:

~~~
dn: CN=CLIENT,CN=Computers,DC=local,DC=example
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: user
objectClass: computer
cn: CLIENT
[...]
servicePrincipalName: HOST/CLIENT
servicePrincipalName: HOST/client.local.example
[...]
distinguishedName: CN=CLIENT,CN=Computers,DC=local,DC=example
~~~

Just add a line here with a fully qualified `userPrincipalName` "duplicating"
the `host` SPN (but including the kerberos realm) like this:

~~~
userPrincipalName: host/client.local.example@LOCAL.EXAMPLE
~~~

After saving this modified computer account, a system-wide mount using the
`host` SPN will work on this machine.

