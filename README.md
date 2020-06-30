# Plerd, the jjohn fork

This is a fork of the very excellent blog software [Plerd](https://github.com/jmacdotorg/plerd).  I don't expect anyone but me to be interested in this fork.  If you want production-ready, supported code, please use the original Plerd

# Install

1. git clone the project from github (there is no CPAN install option) into a local sandbox (e.g. plerd_sandbox)
2. cd plerd_sandbox
3. cpanm --installdeps .

This version of plerd does not attempt to install to the wider system, save for cpanm.

I recomending using plenv to have a modern perl on your system.  If you do use plenv, cpanm will install the modules into your home directory.   You should not need super-user privileges to run this.

4. (for Bash-like shells) add:

```
  export PLERD_HOME=/full/path/to/plerd_sandbox
```

to your .bashrc and either source the file or log back into your terminal.

Get some confidence in the system by running 'make' in the plerd_sandbox directory.  This runs a series of tests in the t directory.

# Run

1. cd plerd_sandbox
2. bin/plerdcmd --init --verbose

This will create a top-level .plerd.conf file in your home directory along with a 'plerd' folder.

You could move your markdown files into plerd/source and type:

   plerdcmd --publish-all --verbose

That will render all the md source as HTML in plerd/docroot.

You may change these directory options in .plerd.conf so that plerd gets its source from a dropbox folder and publishes to your system's httpd docroot.

There is no system daemon in this version.  Instead, set up a cron job to run plerdcmd --publish-all.

# Author

Original modifications: June 2020

Joe Johnston <jjohn@taskboy.com>
