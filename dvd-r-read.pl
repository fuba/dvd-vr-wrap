#!/usr/bin/perl
use v5.30;
use DVD::Read;

sub usage {
    return <<USAGE
NAME
    dvd-r-read.pl

SYNOPSIS
    sudo carton exec dvd-r-read.pl [device] [mountpoint] [targetdir]

DESCRIPTION
    device: device of DVD drive (required)
    mountpoint: path for mounting DVD (required)
    targetdir: path for saving files (default: "./")
USAGE
}

my $device = (shift @ARGV) // die usage();
my $dvd_mount_path = (shift @ARGV) // die usage();
die usage() unless -e $dvd_mount_path;
my $save_target = (shift @ARGV) // "./";
die usage() unless -e $save_target;

my $dvd = DVD::Read->new($device);
print $dvd->volid;
print "\n";
foreach (1 .. $dvd->titles_count) {
  print "$_ : ";
  print $dvd->title_chapters_count($_);
  print " chapters\n";
  my $title = $dvd->get_title($_);
  print $title;
}

