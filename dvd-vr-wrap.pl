#!/usr/bin/perl
use strict;
use warnings;
use v5.34;
use Data::Dumper;

sub usage {
    return <<USAGE
NAME
    dvd-vr-wrap.pl

SYNOPSIS
    sudo dvd-vr-wrap.pl [device] [mountpoint] [dvd_vr] [targetdir]

DESCRIPTION
    device: device of DVD drive (required)
    mountpoint: path for mounting DVD (required)
    dvd_vr: path for dvd-vr (default: "dvd-vr")
    targetdir: path for saving files (default: "./")
USAGE
}

my $device = (shift @ARGV) // die usage();
my $dvd_mount_path = (shift @ARGV) // die usage();
die usage() unless -e $dvd_mount_path;
my $dvd_vr_path = (shift @ARGV) // "dvd-vr";
die usage() unless -e $dvd_vr_path;
my $save_target = (shift @ARGV) // "./";
die usage() unless -e $save_target;

say "read $device, move to $save_target";
chdir $save_target;

my $retry = 5;
while (!system("mount $device $dvd_mount_path")) {
    sleep 3;
    if (--$retry <= 0) {
        die "mount failed";
    }
}
my $date2info = get_info($dvd_vr_path, $dvd_mount_path);
say Dumper $date2info;

extract($dvd_vr_path, $dvd_mount_path);
rename_extracted($date2info);
system("eject $device");
sleep(5);
system("eject $device");
sleep(5);
system("eject $device");
sleep(5);
system("eject $device");
sleep(5);
system("eject $device");
say "DONE";
exit;

sub rename_extracted {
    my $date2info = shift;

    opendir my $dh, './';
    while (my $file = readdir($dh)) {
        next if $file =~ /\A\./;
        my $date = $file;
        $date =~ s/\.vob//;
        $date =~ s/_/ /;
        
        my $info = $date2info->{programs}->{$date};
        next if !$info;
        my $format = $date2info->{formats}->{$info->{"vob format"}};
        next if !$format;

        # TODO: better formatting
        my $text_date = $date;
        $text_date =~ s/\:/：/g;
        $text_date =~ s/ /　/g;

        my $title = $info->{title};
        $title =~ s{\/}{／}g;
        $title =~ s/ /　/g;
        $title =~ s/\:/：/g;

        my $new_name = sprintf(
            "%s（%s　%s）.vob",
            $title,
            $text_date,
            $format->{resolution},
        );

        say "rename $file to $new_name";
        rename($file, $new_name);
    }
    closedir $dh;
}


sub extract {
    my ($app, $path) = @_;
    if (!-e $dvd_mount_path.'/DVD_RTAV') {
        die "no DVD_RTAV";
    }
    eval {
        system("$app $path/DVD_RTAV/VR_MANGR.IFO $path/DVD_RTAV/VR_MOVIE.VRO");
    };
    if ($@) {
        say "extract was failed: $@";
    }
}

sub get_info {
    my ($app, $path) = @_;
    if (!-e $dvd_mount_path.'/DVD_RTAV') {
        die "no DVD_RTAV";
    }

    my $text = `$app $path/DVD_RTAV/VR_MANGR.IFO`;
    my @lines = split /\n/, $text;
    my $i = 0;
    my %formats;
    my %programs;

    while (defined $lines[$i]) {
        if ($lines[$i] =~ /VOB format (\d+)/) {
            my $format_num = $1;
            $formats{$format_num} = {};
            for my $j (1..6) {
                if ($lines[$i+$j] =~ /^([^\:\s]+)\s*\:\s*(.+)/) {
                    $formats{$format_num}->{$1} = $2;
                }
            }
            $i += 6;
            $i++;
            next;
        }

        if ($lines[$i] =~ /\Atv_system/) {
            $formats{1} = {};
            for my $j (0..5) {
                if ($lines[$i+$j] =~ /^([^\:\s]+)\s*\:\s*(.+)/) {
                    $formats{1}->{$1} = $2;
                }
            }
            $i += 5;
            $i++;
            next;
        }

        if ($lines[$i] =~ /num  : (\d+)/) {
            my $program_num = $1;
            my $data = {};

            for my $j (1..5) {
                if ($lines[$i+$j] && $lines[$i+$j] =~ /^([^\:]+)\s*\:\s*(.+)/) {
                    my ($key, $value) = ($1, $2);
                    s/\s+\z// for ($key, $value);
                    $data->{$key} = $value;
                }
            }
            $data->{"vob format"} //= 1;
            $programs{$data->{date}} = $data;
        }

        $i++;
    }

    return {
        formats => \%formats,
        programs => \%programs,
    };
}
