#!/usr/bin/env perl
# Clean up timer file: remove empty chunk lines and orphaned comment lines
# from all weeks except the current one (first two paragraphs).
#
# "Empty chunk line" = a line in a data paragraph matching /^name\t$/
# "Orphaned comment" = a comment line whose timer has no chunks-with-data
#                      line in the same week's data paragraph.
#
# Usage: perl cleanup-timer.pl < timer-new > timer-new.cleaned

use strict;
use warnings;

my @paragraphs;
my @current;

# Parse file into paragraphs (groups of non-blank lines separated by blank lines)
while (my $line = <STDIN>)
{
    chomp $line;
    if ($line eq '')
    {
        push @paragraphs, [@current] if @current;
        push @paragraphs, [];  # placeholder for the blank-line separator
        @current = ();
    }
    else
    {
        push @current, $line;
    }
}
push @paragraphs, [@current] if @current;

# First two non-empty paragraphs are the current week; pass through unchanged.
# Paragraphs come in pairs: data (even-indexed content para) + comments (odd).
# Blank-line separators (empty arrayrefs) are interspersed.

my $content_para = 0;  # count of non-empty paragraphs seen
my $removed_chunks  = 0;
my $removed_comments = 0;

for my $i (0 .. $#paragraphs)
{
    my $para = $paragraphs[$i];

    # Blank-line separator: just emit it
    if (@$para == 0)
    {
        print "\n";
        next;
    }

    $content_para++;

    # First two content paragraphs = current week: pass through as-is
    if ($content_para <= 2)
    {
        print "$_\n" for @$para;
        next;
    }

    # Determine if this is a data paragraph or a comment paragraph.
    # Comment paragraphs have lines starting with "name:\t"
    # Data paragraphs have lines starting with "name\t"
    my $is_comment = ($para->[0] =~ /^[^:\t]+:\t/);

    if (!$is_comment)
    {
        # Data paragraph: collect which timers have actual chunk data,
        # and filter out empty-chunk lines.
        my %has_chunks;
        my @kept;
        for my $line (@$para)
        {
            if ($line =~ /^([^\t]+)\t$/)
            {
                # Empty chunk line (name + tab, nothing after)
                $removed_chunks++;
            }
            else
            {
                # Has chunk data (or is :AVAILABILITY etc.)
                if ($line =~ /^([^\t]+)\t/)
                {
                    $has_chunks{$1} = 1;
                }
                push @kept, $line;
            }
        }
        # Stash the has_chunks info for the next (comment) paragraph
        $paragraphs[$i] = { kept => \@kept, has_chunks => \%has_chunks };
        print "$_\n" for @kept;
    }
    else
    {
        # Comment paragraph: find the preceding data paragraph's has_chunks
        my %has_chunks;
        for (my $j = $i - 1; $j >= 0; $j--)
        {
            if (ref $paragraphs[$j] eq 'HASH')
            {
                %has_chunks = %{ $paragraphs[$j]{has_chunks} };
                last;
            }
        }

        my @kept;
        for my $line (@$para)
        {
            if ($line =~ /^([^:\t]+):/)
            {
                my $name = $1;
                if (!$has_chunks{$name})
                {
                    $removed_comments++;
                    next;
                }
            }
            push @kept, $line;
        }
        print "$_\n" for @kept;
    }
}

warn "Removed $removed_chunks empty chunk lines\n";
warn "Removed $removed_comments orphaned comment lines\n";
