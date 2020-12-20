% Advocacy: Why I personally prefer *FreeBSD* over *Linux*
% Felix Palmen <felix@palmen-it.de>
% 2020-12-20

These are my personal reasons to prefer *FreeBSD* over *Linux*. I do not
expect them to be useful to anyone, but *if* you read them, maybe they are
somewhat interesting.

## 0. Why I tested *FreeBSD* at all

So, *GNU/Linux* is a fine and widespread opensource Unix-like operating system
with nowadays lots of support, even from commercial entities. Why would you
even bother looking at alternatives?

Well, for me, as for many others, the issue was `systemd`.

Now, this is a flamebait on a similar level as stating `vim` is better than
`emacs` (spoiler: it is … hehe). No doubt there were issues with the classic
`sysv-init` *GNU/Linux* used for a long time. And no doubt any init system
based on shell scripting will always have its shortcomings.

But then, `systemd` looks to me like a “solution” that actually makes things
worse. There are lots of reasons, and I don't want to repeat all of them here.
The most important ones are: It tries to do too much, and it does it in a very
intrusive way.

*FreeBSD* never used `sysv-init`. To this day, it uses a classic BSD-style
`init` with `mewburn-rc` init scripts. This *does* have the inherent
shortcomings of a purely shell-script based boot process, and of course there
are discussions in BSD communities as well whether it should be replaced by
something different. For me, it works pretty well, and we will see what the
future brings.

But this was only what made me test *FreeBSD*. Let's get to the actual
advantages I found.

## 1. ZFS

In case you don't know ZFS: It's more than a filesystem. It also includes
volume management (with quick and simple snapshots and clones) and software
RAID, all integrated. My personal claim is: you can't have a better opensource
storage solution right now.

On *FreeBSD*, ZFS is an integral part of the base system. It works well with
jails and for backing virtual machines with *bhyve*, and you can easily boot
your system from ZFS. Of course, it is available for *GNU/Linux* as well, but
it will (probably) never be integrated there for licensing issues.

*GNU/Linux* instead tries to push btrfs, which aims to be kind of similar to
ZFS. Well… to this day, I'd say it's not really there.

This kind of leads to the next topic:

## 2. The BSD license

Licensing of opensource software is a controversial issue. It depends a lot on
your definition of freedom.

*GNU/Linux* uses the GPL (General Public License). This license contains a lot
of restrictions, in an attempt to ensure freedom. A key component is that it
requires any “derivative work” to be GPL licensed as well. In my personal
view, complicated restrictions to ensure freedom are an oxymoron. It also
creates the real-life problem that often, other opensource licenses are
“incompatible”, which is the reason why ZFS can't be integrated with
*GNU/Linux*.

The BSD licenses (there are a few different variations) are extremely simple.
In a nutshell, they allow you to do whatever you want with the code. You can
even use it in a commercial product. They just require you to “give credit”
when you use the code in your own work. IMHO, this is enough, as everyone will
be informed that there *is* an opensource project some code was taken from. It
matches my personal definition of freedom, so in the rare cases I publish
opensource software myself, I use a BSD style license as well.

Actually, apart from the eventual GPL incompatibility issues, this is a
philosophical discussion, so, back to more technical topics.

## 3. A whole, self-contained OS

*FreeBSD* (and any other BSD) is, in contrast to *GNU/Linux*, a complete,
self-contained operating system. With *GNU/Linux*, you get individual software
packages (the most essential being *Linux* itself as the kernel, GNU binutils,
gcc and glibc as the toolchain and GNU coreutils as the most basic parts of a
userland) and have to integrate them together to form a working operating
systems. Distributions will do that work for you.

With *FreeBSD*, you get a single source tree, compile it, and have a complete
operating system ready to run.

So, why is this an advantage? Stability! You can always rely on all components
working together with no issues. In the *GNU/Linux* world, distributions are
responsible for that. With *FreeBSD*, you get one official version that “just
works”. You might argue that's not really important, given you use a good
*GNU/Linux* distribution. Indeed, from a user's perspective, the fact that a
self-contained OS has more “inner logic” is nothing you will directly feel. At
least, it gives you the chance to get things like security patches directly
from upstream and be fine, with no time lost for a distribution that has to
make sure things work nicely together again.

For me personally, another advantage is more important:

## 4. Stable system or rolling release?

Why not both?

With *FreeBSD* (and any other BSD, as far as I know), you can follow stable
releases for the OS itself, that go through a classic release engineering
process. Still, you can get ports and/or packages of third-party software from
a “rolling release” repository. This gives you the best of both worlds. You
can have the latest and greatest, bleeding-edge, applications on a well-tested
and stable base system.

I don't know of any *GNU/Linux* distribution following a similar scheme. If
you know one, please tell me!

Of course, this is made possible by:

## 5. The ports system

*FreeBSD* (and again, other BSDs as well) has a second and independent source
tree called “ports”. In *FreeBSD*, ports are organized as “rolling release”,
with quarterly snapshots. They are a huge collection of Makefiles (and some
helping scripts) that manage building third-party software for *FreeBSD*. A
port for a single software package automates everything, from downloading to
(if desired) packaging as a binary installable package.

So, this is the base that makes *FreeBSD* not only an operating system but
also a distribution for software running on it. There are official package
repositories containing packages built using ports for any currently supported
version of *FreeBSD*, from the latest version and also from the current
quarterly snapshot. You can use that like you do with a *GNU/Linux*
distribution and just install the binary packages you want, and it's your
choice whether you want the latest or the (maybe a bit more stable) quarterly
snapshots. As ports are required to always build successfully on any supported
version of *FreeBSD*, you can combine as you please.

But the real power of ports comes when you build them yourself. The system
makes it very easy to configure things that can only be configured at build
time, just set a few options. For the casual ports user, there's even a simple
console UI for selecting these options. You can directly build and install a
port to your system from the ports tree with a few simple commands. If you
need more, there are tools like `poudriere` that allow you to easily build
your own binary package repository from the ports tree, tailored to your
needs.

There's one *GNU/Linux* distribution I know about that has something similar:
*Gentoo* with its “portage”. As I never used *Gentoo*, I can't tell how it
compares to *FreeBSD* ports.

## 6. … and more

Of course, there are more technical things I like, for example *jails* (which
is a kind of container or userspace virtualization and is around for much
longer than e.g. docker) and *bhyve* (the relatively new native hypervisor).
It doesn't make much sense to tell a lot about them I guess, and *GNU/Linux*
has similar solutions for similar problems.

But there are still two “soft factors” that are very important for me:

## 7. Mindset and community

To some extent, *FreeBSD* seems to follow a “cathedral” model (as opposed to
the “bazaar” model favoured in the *GNU/Linux* world). What I mean is that any
development seems to be thorougly thought off. For example, with *GNU/Linux*,
I often see that something isn't perfect, so let's just replace it by
something different. I'll give two examples:

* There once was `devd` for automatically creating device nodes. It had some
  major design flaws. As a result, it was kicked out and replaced by `udev`,
  which is now a part of `systemd`.
* *Linux* used an OSS-compatible interface for sound. There were some
  drawbacks that weren't easy to solve, so it was entirely replaced by a new
  interface called *ALSA* (Advanced Linux Sound Architecture)

*FreeBSD* has both `devd` and an OSS-compatible sound interface based on
`/dev/dsp` devices. With OSS, one problem was that the device was always an
exclusive resource, preventing multiple applications to use the sound hardware
in parallel. *FreeBSD* solved that without changing the interface.

This mindset leads to a much more stable (in terms of APIs) system and avoids
“breaking changes” if possible. Chances are good a software once built for
*FreeBSD* will still run without issues on the latest version.

It doesn't mean the community was “closed”, not at all. Build one sane *port*
for a software you want available in *FreeBSD*, submit it, have it reviewed
and it will be added if it's good. You'll be listed as a contributor very
quickly. Well, try this with a major *GNU/Linux* distribution. Still, the
review process will make sure quality standards are met.

In my experience, the *FreeBSD* community is very welcoming. No elitism, even
“stupid” questions are often answered nicely. But then, such questions are
somewhat unlikely anyways, because of

## 8. Documentation

Seriously, *FreeBSD* has the best documentation I have ever seen on any
opensource project.

The “online help” is classic UNIX style with manpages. While GNU info might
have more features, manpages are simpler, but after all, the format isn't that
important, important is the content.

On *FreeBSD* you will find a manpage for almost every available kernel driver!

But it doesn't stop there, there's also a handbook (available online and
installable) that guides you through almost everything you might want to do
with your system. And there's a “porter's handbook” for those interested in
creating their own ports with a lot of helpful chapters. And even more…

## 9. Why not?

Please don't blame me if you give *FreeBSD* a try and you aren't satisfied.
There's never a “one size fits all” and here I'll try to list a few reasons
why you might *not* like *FreeBSD*:

* It's not that widespread. This has consequences like sometimes, you won't
  find the application you want for *FreeBSD*, or it might be out of date.
  Sometimes you might not find a driver you need.
* There's a real *docker* hype lately. It won't work (well) on *FreeBSD*.
  There are *jails*, which is technically very similar but much older. If you
  want to run *docker* stuff, it won't help you much. You won't profit from
  the huge ecosystem that emerged around *docker*.
* *FreeBSD* **never** holds your hand (if you don't count the excellent
  documentation). There's no automatic configuration. The defaults mostly
  match a server workload; if you want to use it on a desktop, you have a lot
  of manual work to do and of course install many packages. But then, for the
  simple-to-setup-desktop, there are distributions/derivates like for example
  *GhostBSD*.
* There are probably many more…

