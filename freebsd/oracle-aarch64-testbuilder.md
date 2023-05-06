% A ports test builder for aarch64 in Oracle Cloud
% Felix Palmen <zirias@FreeBSD.org>
% 2023-05-06

Since `aarch64` moved to Tier-1 for FreeBSD, it's a good idea to also test
your ports on that architecture. But if you don't own hardware for that, you
will quickly run into limitations with the `qemu-user-static` plus
`native-xtools` approach for cross-building. Some ports just won't work with
this.

One possible solution is to subscribe to the Oracle Cloud. They offer some
resources as "always free"; you can use them to configure one aarch64 machine
with specs good enough for occassional ports testing.

At the moment, you can pick one FreeBSD RELEASE image, which will give you a
root partition with UFS. For ports testing with `poudriere`, you will need ZFS
to do it efficiently, and you *should* run `-CURRENT` to also test that. This
document describes the steps needed to get there.

# 1. Preparations

If you don't use Oracle Cloud at the moment, register there. You will need to
trust them with your credit card info, even if you will only use "always free"
resources.

In their portal, look for "compute instances". You can create an "Ampere"
virtual machine there. I won't describe the full process, it should be more or
less obvious anyways and might change in details. Just a few hints:

* You will find a FreeBSD image in the "partner images" area. At the moment of
  writing this, it will install 13.1-RELEASE.
* Take care to check how many resources are "always free". At the moment, for
  a single machine running 24/7, this would be:
  - 4 CPUs
  - 24GiB RAM
  - 200GiB boot volume
* For easy access, I recommend to assign a public IPv4 address and
  upload/paste your public SSH key. You can use that later to log in as
  `root`.

# 2. Build, install and boot a temporary system

After first login, check the partition table with `gpart show`. For me, it
looked like this:

    $ gpart show
    =>        3  419430389  da0  GPT  (200G)
              3      66584    1  efi  (33M)
          66587    2097152    2  freebsd-swap  (1.0G)
        2163739  417266653    3  freebsd-ufs  (199G)

So, in all the following text, I assume the system partition is `da0p3` and
the swap partition is `da0p2`. **Make sure to adapt the following commands if
your machine has different partition numbers!**

We will first abuse the swap partition to install a temporary system, so we
can then create a zpool on `da0p3` in the next step. Execute the following
commands:

~~~{.sh}
$ pkg install git-tiny
$ cd /usr/src
$ git clone https://git.freebsd.org/src.git .
$ cat - >/etc/src.conf
WITHOUT_ACCT=yes
WITHOUT_ACPI=yes
WITHOUT_APM=yes
WITHOUT_ASSERT_DEBUG=yes
WITHOUT_AT=yes
WITHOUT_ATM=yes
WITHOUT_AUDIT=yes
WITHOUT_AUTOFS=yes
WITHOUT_BHYVE=yes
WITHOUT_BLACKLIST=yes
WITHOUT_BLUETOOTH=yes
WITHOUT_BOOTPARAMD=yes
WITHOUT_BOOTPD=yes
WITHOUT_BSDINSTALL=yes
WITHOUT_BSNMP=yes
WITHOUT_CALENDAR=yes
WITHOUT_CAPSICUM=yes
WITHOUT_CCD=yes
WITHOUT_CLANG_FULL=yes
WITHOUT_CUSE=yes
WITHOUT_CXBGETOOL=yes
WITHOUT_DEBUG_FILES=yes
WITHOUT_DICT=yes
WITHOUT_EXAMPLES=yes
WITHOUT_FINGER=yes
WITHOUT_FMTREE=yes
WITHOUT_FREEBSD_UPDATE=yes
WITHOUT_FTP=yes
WITHOUT_GAMES=yes
WITHOUT_GNU_DIFF=yes
WITHOUT_GPIO=yes
WITHOUT_HAST=yes
WITHOUT_HTML=yes
WITHOUT_INETD=yes
WITHOUT_IPFILTER=yes
WITHOUT_IPFW=yes
WITHOUT_ISCSI=yes
WITHOUT_LLVM_ASSERTIONS=yes
WITHOUT_LLVM_COV=yes
WITHOUT_LLVM_TARGET_ALL=yes
WITHOUT_LOCATE=yes
WITHOUT_LPR=yes
WITHOUT_MAIL=yes
WITHOUT_MLX5TOOL=yes
WITHOUT_NDIS=yes
WITHOUT_NETCAT=yes
WITHOUT_NIS=yes
WITHOUT_NTP=yes
WITHOUT_OFED=yes
WITHOUT_OPENMP=yes
WITHOUT_PF=yes
WITHOUT_PMC=yes
WITHOUT_PORTSNAP=yes
WITHOUT_PPP=yes
WITHOUT_PROFILE=yes
WITHOUT_RBOOTD=yes
WITHOUT_ROUTED=yes
WITHOUT_SHAREDOCS=yes
WITHOUT_TALK=yes
WITHOUT_TCP_WRAPPERS=yes
WITHOUT_TCSH=yes
WITHOUT_TELNET=yes
WITHOUT_TESTS=yes
WITHOUT_TFTP=yes
WITHOUT_UNBOUND=yes
WITHOUT_WIRELESS=yes
WITH_MALLOC_PRODUCTION=yes
KERNCONF=GENERIC-NODEBUG
# hit <CTRL+D>
$ make -j4 buildworld buildkernel
$ swapoff -a
$ sed -i '' -e '/swap/d' /etc/fstab
$ gpart modify -i 2 -t freebsd-ufs da0
$ newfs /dev/da0p2
$ mount -t ufs /dev/da0p2 /mnt
$ make DESTDIR=/mnt distrib-dirs distribution installworld installkernel
$ echo 'vfs.root.mountfrom="ufs:/dev/da0p2"' >>/boot/loader.conf
$ cp /etc/rc.conf /mnt/etc/
$ cp /etc/fstab /mnt/etc/
$ cp /etc/ssh/sshd_config /mnt/etc/ssh/
$ cp /boot/loader.conf /mnt/boot/
$ cp -R /root/.ssh /mnt/root/
$ gpart modify -l rootfs-old -i 3 da0
$ gpart modify -l rootfs -i 2 da0
$ umount /mnt
$ shutdown -r now
~~~

After reboot, you should see `/` is now mounted from `/dev/da0p2`.

# 3. Create a zpool and install a full -CURRENT there

In this next step, we will create the zpool and use its `/usr/src` and
`/usr/obj` datasets to build a full -CURRENT. We will also enable *meta-mode*
for this, so future upgrades only need to build what changed.

Here are the commands to do that:

~~~{.sh}
$ gpart modify -i 3 -t freebsd-zfs da0
$ zpool create zroot /dev/da0p3
$ zfs set mountpoint=/zroot zroot
$ zfs create -o mountpoint=none zroot/ROOT
$ zfs create -o mountpoint=/mnt -o canmount=noauto -o readonly=off zroot/ROOT/default
$ zfs mount zroot/ROOT/default
$ zpool set bootfs=zroot/ROOT/default zroot
$ zfs create -o mountpoint=/mnt/tmp -o exec=on -o setuid=off zroot/tmp
$ zfs create -o mountpoint=/mnt/usr -o canmount=off zroot/usr
$ zfs create zroot/usr/home
$ ln -s usr/home /mnt/home
$ zfs create zroot/usr/src
$ zfs create zroot/usr/obj
$ zfs create -o mountpoint=/mnt/var -o canmount=off zroot/var
$ zfs create -o exec=off -o setuid=off zroot/var/audit
$ zfs create -o exec=off -o setuid=off zroot/var/crash
$ zfs create -o exec=off -o setuid=off zroot/var/log
$ zfs create -o atime=on zroot/var/mail
$ zfs create -o setuid=off zroot/var/tmp
$ mount -t nullfs /mnt/usr/src /usr/src
$ mount -t nullfs /mnt/usr/obj /usr/obj
$ mkdir /mnt/usr/local
$ mount -t nullfs /mnt/usr/local /usr/local
$ pkg install git-tiny
$ cd /usr/src
$ git clone https://git.freebsd.org/src.git .
$ cat - >/etc/src.conf
WITHOUT_ASSERT_DEBUG=yes
WITHOUT_LLVM_ASSERTIONS=yes
WITHOUT_TESTS=yes
WITH_MALLOC_PRODUCTION=yes
KERNCONF=GENERIC-NODEBUG
# hit <CTRL+D>
$ cat - >/etc/src-env.conf
WITH_META_MODE=yes
# hit <CTRL+D>
$ kldload filemon
$ make -j4 buildworld buildkernel
$ make DESTDIR=/mnt BATCH_DELETE_OLD_FILES=yes distrib-dirs distribution installworld installkernel delete-old delete-old-libs
$ sed -i '' -e 's,ufs.*,zfs:zroot/ROOT/default",' /boot/loader.conf
$ cp /etc/src*.conf /mnt/etc/
$ cp /etc/rc.conf /mnt/etc/
$ cp /etc/ssh/sshd_config /mnt/etc/ssh/
$ cp /boot/loader.conf /mnt/boot/
$ cp /mnt/boot/loader.efi /boot/efi/EFI/BOOT/bootaa64.efi
$ cp -R /root/.ssh /mnt/root/
$ touch /mnt/etc/fstab
$ cd
$ umount /usr/src
$ umount /usr/obj
$ umount /usr/local
$ rm -fr /mnt/usr/local
$ zfs umount -a
$ umount /mnt
$ zfs set mountpoint=/ zroot/ROOT/default
$ zfs set mountpoint=/tmp zroot/tmp
$ zfs set mountpoint=/usr zroot/usr
$ zfs set mountpoint=/var zroot/var
$ zpool export zroot
$ umount /boot/efi
$ shutdown -r now
~~~

After that reboot succeeded, you should see the system running from a ZFS root
now. We will do some minor adjustments and re-enable swap, and then reboot
again just to check everything works correctly.

Here you might want to first add `filemon` to `kld_list` in `/etc/rc.conf`,
so it's always available for building with *meta-mode* later. Then, also do
the following steps.

~~~{.sh}
$ sed -i '' -e '/opensolaris/d' -e '/mountfrom/d' /boot/loader.conf
$ gpart modify -i 2 -t freebsd-swap -l swap da0
$ dd if=/dev/zero of=/dev/da0p2 bs=1M
$ cat - >/etc/fstab
# Device        Mountpoint      FStype  Options         Dump    Pass#
/dev/gpt/swap   none            swap    sw              0       0
# hit <CTRL+D>
$ etcupdate extract
$ shutdown -r now
~~~

# 4. Basic poudriere setup, build/install packages

The following commands are really just recommendations for setting up
poudriere. They will install poudriere jails of all currently supported
RELEASE versions (at the time of writing 12.4-RELEASE and 13.2-RELEASE) and
manually create a -CURRENT jail from our source tree. A ports tree for
poudriere will be fetched with `git`.

Then, we'll bulk build a small list of packages (the example here shows what I
find useful for work on ports), configure `pkg` to use our local repository,
and install them.

~~~{.sh}
$ pkg install git-tiny poudriere-devel
$ vi /usr/local/etc/poudriere.conf
~~~
Here, you should configure the following:

* uncomment the `ZPOOL` setting
* configure `FREEBSD_HOST` as explained
* configure `DISTFILE_CACHE`, I recommend `${BASEFS}/data/distfiles`
* uncomment `ALLOW_MAKE_JOBS=yes`
* uncomment `PACKAGE_FETCH_BRANCH=latest`

~~~{.sh}
$ poudriere jail -c -j 124 -v 12.4-RELEASE -m ftp
$ poudriere jail -c -j 132 -v 13.2-RELEASE -m ftp
$ zfs create zroot/poudriere/jails/14
$ cd /usr/src
$ make DESTDIR=/usr/local/poudriere/jails/14 BATCH_DELETE_OLD_FILES=yes distrib-dirs distribution installworld delete-old delete-old-libs
$ etcupdate extract -D /usr/local/poudriere/jails/14
$ poudriere jail -c -j 14 -v 14.0-CURRENT -M /usr/local/poudriere/jails/14 -m null -S /usr/src
$ zfs create zroot/poudriere/data/distfiles
$ zfs create zroot/poudriere/ports/default
$ cd /usr/local/poudriere/ports/default
$ git clone https://git.freebsd.org/ports.git .
$ cd
$ poudriere ports -c -p default -M /usr/local/poudriere/ports/default -m null
$ cat - >ports.txt
devel/git
devel/rclint
editors/vim
ports-mgmt/portfmt
ports-mgmt/portlint
ports-mgmt/poudriere-devel
shells/zsh
sysutils/tmux
# hit <CTRL+D>
$ poudriere bulk -j 14 -p default -f ~/ports.txt
$ ln -s 14-default /usr/local/poudriere/data/packages/local
$ mkdir -p /usr/local/etc/pkg/repos
$ cat - >/usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: { enabled: NO }
# hit <CTRL+D>
$ cat - >/usr/local/etc/pkg/repos/local.conf
local: { url: file:///usr/local/poudriere/data/packages/local }
# hit <CTRL+D>
$ pkg upgrade -f
$ pkg install git vim portlint portfmt rclint tmux zsh
$ pkg autoremove
$ pkg clean
~~~

# 5. Test some of your ports

Yes, please do so ;)
