#!/usr/bin/perl -w
#
# $Id: modefix.pl,v 3.6 2003/01/13 05:28:42 jmates Exp $
#
# Copyright (c) 2000-2002, Jeremy Mates.  This script is free
# software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
#
# Run perldoc(1) on this file for additional documentation.
#
######################################################################
#
# REQUIREMENTS

require 5;

use strict;

######################################################################
#
# MODULES

use Carp;         # better error reporting
use Getopt::Std;  # command line option processing

use File::Find;   # recursive directory walking

######################################################################
#
# VARIABLES

my $VERSION;
($VERSION = '$Revision: 3.6 $ ') =~ s/[^0-9.]//g;

my (
  %opts,     $dirmode, $filemode, $user,   $userid,
  $group,    $groupid, $verbose,  $quiet,  %badgroups,
  %badperms, $skip,    $prune,    $report, $parent
);

my $recursive = 1;

######################################################################
#
# MAIN

# deal with command line options
getopts('h?p:s:d:f:u:g:Grvql', \%opts);

help() if exists $opts{'h'} || exists $opts{'?'};

# make sure we got valid arguments...
unless (exists $opts{'u'}
  or exists $opts{'g'}
  or exists $opts{'f'}
  or exists $opts{'d'}) {
  die "Error: no action flag(s) specified\n";
}
if (exists $opts{'G'} and !exists $opts{'u'}) {
  die "Error: the -G flag requires -u\n";
}

# set some misc. options...
$verbose = 1 if exists $opts{'v'};
$report  = 1 if exists $opts{'r'};
if (exists $opts{'q'}) {
  $verbose = 0;
  $report  = 0;
  $quiet   = 1;
}

$recursive = 0 if exists $opts{'l'};

$skip  = $opts{'s'} if exists $opts{'s'};
$prune = $opts{'p'} if exists $opts{'p'};

# read in action flags

# get directory mode to set
if (exists $opts{'d'}) {
  my $temp_dirmode = $opts{'d'};

  if ($temp_dirmode =~ m/^\d{3,4}$/) {

    # internal number in oct mode for chmod compatibility
    $dirmode = oct $temp_dirmode;

  } else {

    # or an array ref for apply_mode to use
    $dirmode = parse_mode($temp_dirmode);

    die "Error: invalid directory mode $temp_dirmode\n" unless $dirmode;
  }
}

# get file mode to set
if (exists $opts{'f'}) {
  my $temp_filemode = $opts{'f'};

  if ($temp_filemode =~ m/^\d{3,4}$/) {
    $filemode = oct $temp_filemode;

  } else {
    $filemode = parse_mode($temp_filemode);

    die "Error: invalid file mode $temp_filemode\n" unless $filemode;
  }
}

# user to set
if (exists $opts{'u'}) {
  my $temp_user = $opts{'u'};

  # check whether user:group notation in use...
  ($temp_user, $group) = split ':', $temp_user, 2;

  # by userid, otherwise attempt by user name
  if ($temp_user =~ m/^\d+$/) {

    # check that this userid exists in passwd file
    unless ($user = getpwuid $temp_user) {
      warn 'Warning: unknown userid ', $temp_user, "\n"
       unless $quiet;
    }
    $userid = $temp_user;

  } else {

    # need the userid, regardless; can't pull out in scalar mode
    # as root's 0 id triggers the or die... :)
    (undef, undef, $userid, $groupid) = getpwnam $temp_user
     or die 'Error: no such user ', $temp_user, "\n";
    $user = $temp_user;
  }
}

unless (exists $opts{'G'}) {

  # need to undefine $groupid, unless there's -g or $group crap
  unless (exists $opts{'g'} || defined $group) {
    undef $groupid;

  } else {
    my ($members, $temp_groupid);  # for sanity checking
    my $temp_group;
    $temp_groupid = $groupid if defined $groupid;

    if (exists $opts{'g'} || defined $group) {

      # if group already defined, using -u user:group notation,
      # ignore the -g option!
      if (defined $group) {
        $temp_group = $group;
      } else {
        $temp_group = $opts{'g'};
      }

      # by groupid, otherwise attempt by group name
      if ($temp_group =~ m/^\d+$/) {
        unless (($group, undef, $groupid, $members) = getgrgid $temp_group) {

          # hmmm, at least Linux doesn't appear to allow me to
          # set the gid to a non-existant group number in perl...
          die 'Error: unknown groupid ', $temp_group, "\n";
        }
      } else {

        # extract more info on the group they gave us
        ($group, undef, $groupid, $members) = getgrnam $temp_group
         or die 'Error: no such group ', $temp_group, "\n";
      }

      # some user/group sanity checking: check whether user is a member
      # of the group in question
      if ((defined $temp_groupid && $temp_groupid != $groupid)
        && exists $opts{'u'}
        && defined $members) {

        # username had better appear as a word in $members...
        unless ($members =~ m/\b$user\b/o) {
          warn "Warning: $user not member of group $group \n"
           unless $quiet || $userid == 0;
        }
      }
    }
  }
}

# read from STDIN if no args left on command line
chomp(@ARGV = <STDIN>) unless @ARGV;

# and flag the help text if nothing from STDIN
help() unless @ARGV;

# loop over the remaining input, applying mode changes
for (@ARGV) {
  if (-d and $recursive) {
	$parent = $_;
    find({wanted => \&zapit, no_chdir => 1}, $parent);
  } elsif (-e) {
	zapit();
  }
}

if ($report) {

  # report on who was a bad user (e.g. is setting the wrong group)
  # keys are the uid's of bad users
  if (keys %badgroups > 0 && !$quiet) {
    print "Users owning files with improper groups:\n";
    for (keys %badgroups) {
      my ($name, $uid, $gid, $gcos, $dir) = (getpwuid $_)[0, 2, 3, 6, 7];

      print '  ', $name, ':', $_, ':', $gid, ':', $gcos, ':', $dir, "\t",
       $badgroups{$_}, "\n";
    }
    print "\n";
  }

  # and same for the permissions on files
  if (keys %badperms > 0 && !$quiet) {
    print "Users owning files with improper permissions:\n";
    for (keys %badperms) {
      my ($name, $uid, $gid, $gcos, $dir) = (getpwuid $_)[0, 2, 3, 6, 7];

      print '  ', $name, ':', $_, ':', $gid, ':', $gcos, ':', $dir, "\t",
       $badperms{$_}, "\n";
    }
    print "\n";
  }
}

######################################################################
#
# SUBROUTINES
#
# zapit is the File::Find subroutine that gets called for each file

sub zapit {

  # get current user/group ids off of item
  my ($cur_mode, $cur_uid, $cur_gid) = (lstat)[2, 4, 5];

  # remove type from mode, leaving permission
  $cur_mode = $cur_mode & 07777;

  # deal with directories
  if (-d) {

    # see if we should "prune" this directory first
    if (defined $prune) {
      my $result = eval "return 1 if (" . $prune . ");";

      if ($@) {
        chomp $@;
        die "Error: prune eval failure: ", $@;  # croak on errors
      }

      if ($result) {
        $File::Find::prune = 1;
        warn "Pruned: ", $_, "\n" if $verbose;
        return;
      }
    }

    # or whether simply "skipped" over
    if (defined $skip) {
      my $result = eval "return 1 if (" . $skip . ");";

      if ($@) {
        chomp $@;
        die "Error: skip eval failure: ", $@;  # croak on errors
      }

      if ($result) {
        warn "Skipped: ", $_, "\n" if $verbose;
        return;
      }
    }

    # apply mode changes as needed to directory
    if (defined $dirmode) {
      my $new_mode;

      # if ARRAY, do the funky stuff, assume regular octal otherwise
      if (ref $dirmode eq 'ARRAY') {
        $new_mode = apply_mode($cur_mode, $dirmode);
      } else {
        $new_mode = $dirmode;
      }

      # this next bit could be subroutined w/ the filemode change
      # code below being identical...
      if ($new_mode != $cur_mode) {

        # show the offending file if verbose on
        print 'Old mode: ', sprintf("%04o", $cur_mode), "\t", $_,
         "\n"
         if $verbose;

        # attempt the change
        my $result = chmod $new_mode, $_;
        warn "Warning: chmod failure on: ", $_, "\n"
         if $result == 0;

        # log bad permissions
        $badperms{$cur_uid}++ if $report;
      }
    }

  } elsif (-f) {

    # see whether to skip this file
    if (defined $skip) {
      my $result = eval "return 1 if (" . $skip . ");";

      if ($@) {
        chomp $@;
        die "Error: skip eval failure: ", $@;  # croak on errors
      }

      if ($result) {
        warn "Skipped: ", $_, "\n" if $verbose;
        return;
      }
    }

    # set file modes if needed
    if (defined $filemode) {
      my $new_mode;

      # if ARRAY, do the funky stuff, assume regular octal otherwise
      if (ref $filemode eq 'ARRAY') {
        $new_mode = apply_mode($cur_mode, $filemode);
      } else {
        $new_mode = $filemode;
      }

      # only perform the chmod if modes are different...
      if ($new_mode != $cur_mode) {

        # show the offending file if verbose on
        print 'Old mode: ', sprintf("%04o", $cur_mode), "\t", $_,
         "\n"
         if $verbose;

        my $result = chmod $new_mode, $_;

        warn "Warning: chmod failure on: ", $_, "\n"
         if $result == 0;

        # log bad permissions
        $badperms{$cur_uid}++ if $report;
      }
    }
  }

  # same user/group-changing code for both dirs and files here
  if ( (defined $groupid && $groupid != $cur_gid)
    || (defined $userid && $userid != $cur_uid)) {

    # set what to change what to, depending :)
    # || alternation doesn't work as 0 (root's id) fails test!
    my $uid_temp = (defined $userid)  ? $userid  : $cur_uid;
    my $gid_temp = (defined $groupid) ? $groupid : $cur_gid;

    # yak if verbose
    print 'Old UID GID: ', $cur_uid, "\t", $cur_gid, "\t", $_,
     "\n"
     if $verbose;

    my $result = chown $uid_temp, $gid_temp, $_;
    warn "Warning: chown failure on: ", $_, "\n" if $result == 0;

    # log this change so we know whose been setting bad groups
    $badgroups{$cur_uid}++ if defined $groupid && $report;
  }
}

# parse_mode takes incoming ug+rw,o-rwx requests and returns
# an array reference suitable for use in apply_mode().
#
# the array for ug+rw,o-rwx should look like ([1,0660],[0,0007])
#                                                sugo
#
# the first element of the internal anon array is whether to add or
# remove the permission, the second is an octal number representing
# which bits to operate on
sub parse_mode {
  my $temp_mode = shift;

  return unless $temp_mode =~ m/^[augorwxs,+-]+$/;

  my (@modes, $bitmask, $value, $sticky, $mode);

  for (split ',', $temp_mode) {
    my ($what, $operator, $flags) = split /([+-])/, $_, 2;

    return unless $operator and $flags;

    $mode    = 1;           # whether adding or subtracting bits
    $bitmask = 0000;        # default bits to operate on
    $value   = $sticky = 0;

    $what = 'ugo' if $what eq 'a' or $what eq '';

    $value += 4 if $flags =~ /r/;
    $value += 2 if $flags =~ /w/;
    $value += 1 if $flags =~ /x/;

    if ($what =~ /u/) {
      $bitmask |= oct "0${value}00";
      $sticky += 4 if $flags =~ /s/;
    }
    if ($what =~ /g/) {
      $bitmask |= oct "00${value}0";
      $sticky += 2 if $flags =~ /s/;
    }
    if ($what =~ /o/) {
      $bitmask |= oct "000${value}";
      $sticky += 1 if $flags =~ /s/;
    }

    # apply sticky mode to finish off this bitmask
    $bitmask |= oct "${sticky}000";

    # test for remove bit, otherwise assume add bit
    $mode = 0 if $operator eq "-";

    push @modes, [$mode, $bitmask];
  }

  return \@modes;
}

# expects file's current mode and a parse_mode array reference
# returns the mode the file should be changed to
#
# see parse_mode for the format of the modes array
sub apply_mode {
  my $temp_mode = shift;
  my $r_mode    = shift;

  for (@{$r_mode}) {

    # &~ removes bitmask in element from file's permissions,
    # | operator adds bitmask in if necessary
    if ($_->[0] == 0) {
      $temp_mode &= ~$_->[1];
    } else {
      $temp_mode |= $_->[1];
    }
  }

  return $temp_mode;
}

# a standardized help blarb, see perldoc stuff for more meat
sub help {
  print <<"HELP";
$0 [options] file1 [file2 file3 .. fileN]

A unix permissions and ownership changer.

Options for version $VERSION
  -h/?   See this text.
  -v     Verbose mode.
  -r     Print a little report summarizing changes.
  -q     Quiet mode, overrides verbose and report modes.
  -l     Do no recurse into directories (default is to).

 At least one action flag is required:
  -d nn  Directory mode to set, e.g. '2770' or 'g+rx,o-rwx'
  -f nn  File mode to set,      e.g. '660'  or 'ug+rw'
  -u uu  User name to set,      e.g. 'jdoe' or '42'
  -g gg  Group name to set,     e.g. 'goobers' or '1492'

  -G     Use default group for user given by -u (overrides -g)

  -s xx  Perl expression to skip files.
  -p xx  Perl expression to prune directories from search.

Run perldoc(1) on this script for additional documentation.

HELP
  exit;
}

__END__

######################################################################
#
# DOCUMENTATION

=head1 NAME

modefix.pl - a unix permission and ownership changer.

=head1 SYNOPSIS

To manually set the directory and file permissions, as well as the
ownerships under /home/john:

  $ modefix.pl -d 750 -f 640 -u john -g doe /home/john

To ensure all files are group writable, and that others do not have
any access whatsoever to the files under the current directory:

  $ modefix.pl -f g+w,o-rwx .

=head1 DESCRIPTION

modefix.pl is a pure-perl implementation of the following three shell
commands I got tired of running over large filesystems:

  $ find . -type d | xargs chmod 2750
  $ find . -type f | xargs chmod 640
  $ find . | xargs chown john:doe

Which really is not all that efficient or practical, if you want to
skip certain items, prune out a few directories, and only walk over
the same files once.

modefix.pl also does not suffer from the fork penalty find(1) incurs
when xargs(1) does not work and -exec must be used; nor does it run
the risk of ruining your filesystem like a careless recursive chmod(1)
can.

=head2 Normal Usage

  $ modefix.pl [options] [file1 file2 file3 .. fileN]

See L<"OPTIONS"> for details on the command line switches supported.

Any number of directories can be supplied, including none.  In that
case, the script will attempt to read directories from STDIN.

=head1 OPTIONS

modefix.pl accepts a variety of command line options, broken down
into B<Useful Options>, B<Actions>, and B<Search Customization>.

=head2 Useful Options

=over 4

=item B<-h>, B<-?>

View a brief help blarb.

=item B<-v>

Verbose mode, shows files being changed.  Good if you want an audit
trail of what the system looked like before the script ran.

=item B<-r>

Report mode.  Will print out a list summarizing which users owned
files with improper permissions or ownerships, plus a count on on the
magnitude of the problem.

This eases tracking down who is setting improper modes on files.

=item B<-q>

Quiet mode.  Overrides verbose and report modes; only output will be
on chown/chmod failures.

=item B<-l>

Local only; do not recurse into subdirectories.  Good when providing a
set list of files to change, as otherwise the chmod/chown will happen
twice, first on a possible directory recursion, then again on the file
itself.

=back

=head2 Actions

At least one of the following four options are required to make the
script do something besides complain at you:

=over 4

=item B<-d> I<mode>

Directory mode to set.

=item B<-f> I<mode>

File mode to set.

See L<"MORE ON MODES"> for details on the syntax I<mode> accepts.

=item B<-u> I<username>

User name to set.

You can also use the user:group syntax common to chmod(1); this
format will cause the groupname option to be ignored.

=item B<-g> I<groupname>

Group name to set.

User and group names can either be by name, or by id.  If done by
name, chown requires an id to work with, so there had better be a
corresponding system entry for the name supplied.

Also, unless quiet mode is on, modefix.pl warns if you enter a id that
does not exist on the system, or if the user is not a member of the
specified group.

=item B<-G>

Use default group for user given by the required B<-u> option.
Overrides the B<-g> flag.  This allows one to fix the ownerships in a
directory without having to consult what the default group is for the
user:

  $ modefix.pl -G -u john /home/john

=back

=head2 Search Customization

Options exist to supply perl fragments to test whether a particular
file should be skipped or pruned:

=over 4

=item B<-s> I<expression>

Perl expression that will result in the current item (stored in $_)
being skipped if the expression turns out to be true.  Example:

  -s '-d || m/^\.rsrc$/'

Would skip applying the changes to any directories or items named
'.rsrc'. B<Warning>: skip only counts towards whether or not any
actions are performed; modefix.pl will happily apply changes below a
"skipped" directory.

=item B<-p> I<expression>

Perl expression that will result in the current directory (stored in
$_) and anything below that directory being "pruned" from the search.

For example, one can easily prune out all directories lower than the
one supplied as an argument by using the special $parent variable to
check against the current directory; essentially, this turns off the
default recursive behaviour of File::Find:

  -p '$parent ne $_'

=back

Note: Expressions should use the shortcut _ operator in any stat()
calls, to avoid race conditions.  See the entry for stat under
perlfunc(1) for the gory details.

=head1 MORE ON MODES

This section describes the format of the I<modes> parameter that can
be passed to either the B<-f> or B<-d> command line switches.

Both may take either a literal mode to set, such as:

  0750  (optional sticky bit, user bit, group bit, other bit)

Or can take an interpreted expression of arbitrary length and
complexity:

  ug+rw,o-rw,o+s  (mode, operator, flags)

Note that later operations can override earlier ones; for example, we
remove all then add user back in, for the same effect as the octal
mode of 600:

  a-rwxs,u+rw

The various modes recognized are:

  u  user bit
  g  group bit
  o  other bit
  a  all bits

The 'a' mode is shorthand for 'ugo', and can also be specified by
leaving off the mode flag:

  -rx is the same as a-rx or ugo-rx

There are only two operators:

  +  ensure flags are added to mode
  -  ensure flags are removed from mode

And four different flags:

  x  execute bit (1)
  r  read bit (2)
  w  write bit (4)
  s  set sticky bit, based on mode in expression.

The sticky bit acts as follows:

  u+s  set the suid flag
  g+s  set the sgid flag - atalkd(8) likes this on dirs.
  o+s  set the chmod(1) 't' flag, like on /tmp

See chmod(1) for the background on these arguments.

=head1 BUGS

=head2 Reporting Bugs

Newer versions of this script may be available from:

http://sial.org/code/perl/

If the bug is in the latest version, send a report to the author.
Patches that fix problems or add new features are welcome.

=head2 Known Issues

modefix.pl does not deal well with soft links.  Well, File::Find has
trouble with softlinked directories, and I am using lstat, and chmod
support on softlinks appears to vary by OS.

=head1 SEE ALSO

chmod(1), chown(1), File::Find, find(1), perl(1), xargs(1)

=head1 AUTHOR

Jeremy Mates, http://sial.org/contact/

=head1 COPYRIGHT

Copyright (c) 2000-2002, Jeremy Mates.  This script is free
software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 VERSION

  $Id: modefix.pl,v 3.6 2003/01/13 05:28:42 jmates Exp $

=cut
