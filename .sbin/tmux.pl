#!/usr/bin/env perl

# Fix for tmux error "failed to connect to server: No error" on 64-bit Cygwin caused by tmux not deleting its temporary directory upon exit
# Reference: http://superuser.com/questions/760503/cygwin-tmux-failed-to-connect-to-server-no-error

# check if tmux is running
my $running = `ps |grep tmux 2>/dev/null`;

# check if tmux has any temporary directories
chomp(my @tmux_tmp = `ls /tmp |grep tmux`);

# if it isn't running and there are temp directories, remove them
if (! $running && @tmux_tmp) {
  system "rm -rf /tmp/$_" for @tmux_tmp;
}

# run the desired tmux command
my $c = "/usr/bin/tmux";
$c .= " '$_'" for @ARGV;
exec $c;
