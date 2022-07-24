#!/usr/bin/perl
use v5.30;
use Linux::CDROM;

sub usage {
    return <<USAGE
NAME
    watch.pl

SYNOPSIS
    sudo watch.pl [device] [mountpoint] [dvd_vr_wrap] [dvd_vr] [targetdir]

DESCRIPTION
    device: device of DVD drive (required)
    mountpoint: path for mounting DVD (required)
    dvd_vr_wrap: path of dvd-vr-wrap.pl (default: "./dvd-vr-wrap.pl")
    dvd_vr: path for dvd-vr (default: "dvd-vr")
    targetdir: path for saving files (default: "./")
USAGE
}

my $device = (shift @ARGV) // die usage();
my $dvd_mount_path = (shift @ARGV) // die usage();
die usage() unless -e $dvd_mount_path;
my $dvd_vr_wrap_path = (shift @ARGV) // "./dvd-vr-wrap.pl";
die usage() unless -e $dvd_vr_wrap_path;
my $dvd_vr_path = (shift @ARGV) // "dvd-vr";
die usage() unless -e $dvd_vr_path;
my $save_target = (shift @ARGV) // "./";
die usage() unless -e $save_target;

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

        system(
            sprintf(
                "perl %s %s %s %s %s",
                $dvd_vr_wrap_path,
                $device,
                $dvd_mount_path,
                $dvd_vr_path,
                $save_target
            )
        );
        system("umount $device");
        system("eject $device");
        sleep(5);

        if ($d->drive_status != Linux::CDROM::CDS_TRAY_OPEN) {
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

