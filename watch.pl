#!/usr/bin/perl
use v5.30;
use Linux::CDROM;

sub usage {
    return <<USAGE
NAME
    watch.pl

SYNOPSIS
    sudo carton exec watch.pl [device] [mountpoint] [ripping_command] [targetdir]

DESCRIPTION
    device: device of DVD drive (required)
    mountpoint: path for mounting DVD (required)
    ripping_command:
        command for ripping disk.
        you can use templates: _DEVICE_, _MOUNTPOINT_, _TARGETDIR_
        those template strings are replaced by options of this script.
        default: "./dvd-vr-wrap.pl _DEVICE_ _MOUNTPOINT_ dvd_vr _TARGETDIR_"
    targetdir: path for saving files (default: "./")
USAGE
}

my $device = (shift @ARGV) // die usage();
my $dvd_mount_path = (shift @ARGV) // die usage();
die usage() unless -e $dvd_mount_path;
my $ripping_command = (shift @ARGV) // "./dvd-vr-wrap.pl dvd_vr _DEVICE_ _MOUNTPOINT_ _TARGETDIR_";
die usage() unless $ripping_command;
my $save_target = (shift @ARGV) // "./";
die usage() unless -e $save_target;

$ripping_command =~ s/_DEVICE_/\"$device\"/;
$ripping_command =~ s/_MOUNTPOINT_/\"$dvd_mount_path\"/;
$ripping_command =~ s/_TARGETDIR_/\"$save_target\"/;
say "ripping_command = $ripping_command";

my $d = Linux::CDROM->new($device) or die $Linux::CDROM::error;
while (1) {
    if ($d->drive_status == Linux::CDROM::CDS_TRAY_OPEN) {
        say "$device is open";
    }
    elsif ($d->drive_status == Linux::CDROM::CDS_DISC_OK) {
        say "$device is ok";
        my $retry = 5;
        while (!system("mount $device $dvd_mount_path")) {
            sleep 3;
            if (--$retry <= 0) {
                die "mount failed";
            }
        }

        system($ripping_command);
        system("umount $device");
        system("eject $device");
        sleep(5);

        while ($d->drive_status != Linux::CDROM::CDS_TRAY_OPEN) {
            system("eject $device");
            sleep(5);
        }
        say "DONE";
    }
    elsif ($d->drive_status != Linux::CDROM::LINUX_CDROM_NO_TOCHDR) {
        say "status: ".$d->drive_status;
    }
    sleep 5;
}

