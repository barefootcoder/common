#!/usr/bin/env perl

use 5.14.0;
use warnings;
use autodie;
use Getopt::Long;

my $verbose = 0;
my $show_all = 0;
GetOptions(
    'verbose|v' => \$verbose,
    'all|a' => \$show_all,
) or die "Usage: $0 [--verbose] [--all] <email-file> [...]\n";

die "Usage: $0 [--verbose] [--all] <email-file> [...]\n" unless @ARGV;

for my $file (@ARGV)
{
    next unless -f $file;
    
    say "=== $file ===" if @ARGV > 1 || $verbose;
    
    # Use shell tools to extract and decode the content
    # First, extract the base64 content between the MIME boundaries
    # Then decode it and look for the alert message
    
    my $cmd = qq{
        perl -lne 'if (/--MIME_boundary/..eof()){print if /^\\s*\$/..eof()}' "$file" |
        openssl enc -base64 -d 2>/dev/null |
        grep -o '<span[^>]*class="preheader"[^>]*>[^<]*</span>' |
        sed 's/<[^>]*>//g' |
        head -1
    };
    
    my $alert = `$cmd`;
    chomp $alert;
    
    if (!$alert)
    {
        # Try alternate extraction method - look for the actual alert pattern in decoded content
        $cmd = qq{
            perl -lne 'if (/--MIME_boundary/..eof()){print if /^\\s*\$/..eof()}' "$file" |
            openssl enc -base64 -d 2>/dev/null |
            grep -o '\\[Storage & Snapshots\\][^.]*\\.' |
            head -1
        };
        
        $alert = `$cmd`;
        chomp $alert;
    }
    
    if (!$alert)
    {
        # Another alternate - look for IHM alerts
        $cmd = qq{
            perl -lne 'if (/--MIME_boundary/..eof()){print if /^\\s*\$/..eof()}' "$file" |
            openssl enc -base64 -d 2>/dev/null |
            grep -o '\\[IHM\\][^.]*\\.' |
            head -1
        };
        
        $alert = `$cmd`;
        chomp $alert;
    }
    
    if ($alert)
    {
        say "Alert: $alert";
    }
    else
    {
        say "No alert message found";
        
        if ($verbose)
        {
            # Show the subject and date for debugging
            my $subject = `grep '^Subject:' "$file" | head -1`;
            my $date = `grep '^Date:' "$file" | head -1`;
            chomp $subject;
            chomp $date;
            say "  $date" if $date;
            say "  $subject" if $subject;
        }
    }
    
    say "" if @ARGV > 1;
}

# If --all flag is given, show a summary
if ($show_all && @ARGV > 1)
{
    say "\n=== Summary ===";
    
    # Count different types of alerts
    my %alert_types;
    
    for my $file (@ARGV)
    {
        my $cmd = qq{
            perl -lne 'if (/--MIME_boundary/..eof()){print if /^\\s*\$/..eof()}' "$file" |
            openssl enc -base64 -d 2>/dev/null |
            grep -o '<span[^>]*class="preheader"[^>]*>[^<]*</span>' |
            sed 's/<[^>]*>//g' |
            head -1
        };
        
        my $alert = `$cmd`;
        chomp $alert;
        
        if ($alert)
        {
            # Extract just the alert type
            if ($alert =~ /\[(.*?)\]/)
            {
                $alert_types{$1}++;
            }
        }
    }
    
    for my $type (sort keys %alert_types)
    {
        say "$type: $alert_types{$type} alerts";
    }
}