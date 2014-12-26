# repiso

Repiso is a *Re*mote *Piso* manager. In Spain, a piso is an apartment. I use
this tool to easily start or stop computers I have at home, using an always-on
computer connected to my home network and a VPN of mine.

## Features

 - can remotely start, stop or suspend machines
 - can query the availability of a machine (using ping)
 - can automatically connect to a network using NetworkManager (through nmcli) 


## Configuration

You want to create a configuration file in $HOME/.repiso. Start by copying `example.conf` there and edit it. It is written as S-expressions (like scheme) of nested [alists](http://www.gnu.org/software/guile/manual/html_node/Association-Lists.html).

Some explanations:

 - `proxy` is the ssh host name of the always-on machine that will be used for
   wakeonlan.
 - `hosts` is a list of the hosts you want to manage. Each of them need to
   have at least a `hostname` (used to ssh to the machine) and a `mac` entry
   (used for wakeonlan). They can also have a specific `hald-command` or
   `suspend-command`
 - `default` contains the default configuration for the optional settings of
   hosts, as well as the `need-connection` setting (currently not supported on
   a per-host basis). The `need-connection` setting, if it exists, is the name
   of a network (typically a vpn) as known by Network Manager. Repiso will
   ensure a connection to this network is available before running any
   command.


## Usage

As explained if you launch repiso with no argument:

```
  repiso command arg...
  Available commands:
    ping host-id
    ping-all
    start host-id
    stop host-id
    suspend host-id
```



## Dependencies

 - Guile 2.0+
 - wakeonlan (on the "always on" or "proxy" machine)
 - nmcli (optional)
 - an ssh client (tested with openssh)

Only tested on GNU/Linux for now, on Ubuntu 14.04, though I would expect it to
work on other recent distributions.
