#!/usr/bin/perl
use v5.22;

use File::Path qw(make_path);
use Time::Piece;
use DVD::Read;
use Imager;

sub usage {
    return <<USAGE
NAME
    dvd-r-read.pl

SYNOPSIS
    sudo carton exec dvd-r-read.pl [device] [mountpoint] [targetdir] [ffmpeg] [owner:group]

DESCRIPTION
    device: device of DVD drive (required)
    mountpoint: path for mounting DVD (required)
    targetdir: path for saving files (default: "./")
    ffmpeg: ffmpeg path (default: "ffmpeg")
    owner:group: to chown (default: "root:root")
USAGE
}

my $device = (shift @ARGV) // die usage();
my $dvd_mount_path = (shift @ARGV) // die usage();
die usage() unless -e $dvd_mount_path;
my $save_target = (shift @ARGV) // "./";
die usage() unless -e $save_target;
my $ffmpeg = (shift @ARGV) // "ffmpeg";
die usage() unless -e $ffmpeg;
my $owner_group = (shift @ARGV) // "root:root";


my $dvd = DVD::Read->new($device);
my $diskname = $dvd->volid;

my $video_ts_vob = "$dvd_mount_path/VIDEO_TS/VIDEO_TS.VOB";
my @stats = stat($video_ts_vob);
my $atime = localtime($stats[8])->datetime;
$atime =~ tr/\:/_/;

# get screenshot
sub make_path_wrap {
    my $path = shift;
    
    if (!-e $path) {
        make_path($path) or die $!;
    }
}

# prepare directories
my $disk_dir = "$save_target/${diskname}_$atime";
make_path_wrap($disk_dir);
my $work_dir = "$disk_dir/work_dir";
make_path_wrap($work_dir);

my $screenshot_dir = "$work_dir/get_title/screen_shot";
make_path_wrap($screenshot_dir);

my $crop_dir = "$work_dir/get_title/crop";
make_path_wrap($crop_dir);

my $video_dir = "$disk_dir/video";
make_path_wrap($video_dir);

# main
get_screenshot($screenshot_dir, $ffmpeg, $video_ts_vob);
my @crop_files = get_crop($crop_dir, $screenshot_dir, $dvd_mount_path);

get_video_files($dvd_mount_path, $video_dir);

my $chown_command = "chown -R $owner_group \"$disk_dir\"";
system($chown_command);

sub get_video_files {
    my ($dvd_mount_path, $video_dir) = @_;
    my $copy_command = "cp -a \"$dvd_mount_path/VIDEO_TS\" $video_dir";
    system($copy_command);
}

sub get_screenshot {
    my ($screenshot_dir, $ffmpeg, $video_ts_vob) = @_;
    chdir $screenshot_dir;
    my $screenshot_command = "$ffmpeg -i \"$video_ts_vob\" -vcodec png $screenshot_dir/menu%04d.png";

    say $screenshot_command;
    system($screenshot_command);
}

sub get_crop {
    my ($crop_dir, $screenshot_dir, $dvd_mount_path) = @_;

    my @menu_files;
    opendir(my $dh, $screenshot_dir);
    for my $d (readdir($dh)) {
        next if $d =~ /\A\./;
        push @menu_files, "$screenshot_dir/$d";
    }
    closedir($dh);
    exit unless @menu_files;

    my @menu_files_sorted = sort {$a cmp $b} @menu_files;
    my $i = 1;
    my @crop_files;
    LOOP: for my $menu_image (@menu_files_sorted) {
        my $img = Imager->new(
            file => "$menu_image"
        ) or die Imager->errstr();

        for my $row (0..2) {
            for my $col (0..1) {
                my $target_ifo = sprintf("$dvd_mount_path/VIDEO_TS/VTS_%02d_0.IFO", $i);
                if (!-e $target_ifo) {
                    last LOOP;
                }

                my $crop_filename = "$crop_dir/${i}.png";
                say $crop_filename;
                # this setting is only for RD-XS91 menu.
                my $crop = $img->crop(
                    left => $col * 300 + 209 - $row * 1,
                    width => 150,
                    top => $row * 100 + 110,
                    height => 100,
                ); 
                $crop->write(file => $crop_filename);
                push @crop_files, $crop_filename;
                $i++;
            }
        }
    }
    return @crop_files;
}
