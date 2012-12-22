#! /usr/bin/perl

use Toolkit qw<DEBUG_1>;

my $fred = 6;
print STDERR "should get warning => ";
$fred += 'fred';

print "should be 16 ";
say "=> ", DEBUG, $fred;

debuggit(2 => "shouldn't see this");
