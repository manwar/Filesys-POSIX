#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - t/rename.t                             Copyright(c) 2014 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use Test::More ( 'tests' => 4 );
use Test::Deep;
use Test::Exception;
use Test::NoWarnings;

use File::Temp;

use Filesys::POSIX                ();
use Filesys::POSIX::IO::Handle    ();
use Filesys::POSIX::Mem           ();
use Filesys::POSIX::Real          ();
use Filesys::POSIX::Userland::Tar ();
use Filesys::POSIX::Extensions    ();

my $tempdir1 = File::Temp->newdir;
my $tempdir2 = File::Temp->newdir;

open my $fh, '>', "$tempdir1/item1.txt";
close $fh;

my $fs = Filesys::POSIX->new( Filesys::POSIX::Real->new, path => $tempdir1 );

$fs->map( $tempdir1, "/dir" );

my $do_tar = sub {
    open my $tar_fh, ">", "$tempdir2/test.tar";
    my $handle = Filesys::POSIX::IO::Handle->new($tar_fh);
    $fs->tar( $handle, "/dir/" );
    chomp( my @tar = `tar tf $tempdir2/test.tar 2>/dev/null` );
    return @tar;
};

# Case 57600
{
    my @expected = qw(dir dir/item2.txt);
    my %found;

    $fs->rename( 'dir/item1.txt' => 'dir/item2.txt' );

    my @items = $do_tar->();

    foreach my $item (@items) {
        foreach my $expected_item (@expected) {
            $found{$item} = 1 if $item =~ /\Q$expected_item\E(?:|\/)$/;
        }
    }

    is( scalar @expected => scalar keys %found, 'Found the correct number of items archived' );
}

#
# Sanity check: If we use the wrong rename_member method, we get the old, wrong
# behavior for "Real" that forgets to update the state of the real filesystem.
# (This is still correct for Directory objects that aren't based on a real
# filesystem, though.)
#
{
    my @expected = qw(dir dir/item2.txt dir/item3.txt);

    my %found;

    local *Filesys::POSIX::Real::Directory::rename_member;

    $fs->rename( 'dir/item2.txt' => 'dir/item3.txt' );

    my @items = $do_tar->();

    foreach my $item (@items) {
        foreach my $expected_item (@expected) {
            $found{$item} = 1 if $item =~ /\Q$expected_item\E(?:|\/)$/;
        }
    }

    is( scalar @expected => scalar keys %found, 'Found the correct number of items archived after usage of rename_member()' );
}

# Further sanity check: Prove that the parent class's rename_member method is the one being
# used in the previous sanity check.
{
    local *Filesys::POSIX::Real::Directory::rename_member;
    local *Filesys::POSIX::Directory::rename_member;

    throws_ok {
        $fs->rename( 'dir/item3.txt' => 'dir/item4.txt' );
    }
    qr/Can't locate object method "rename_member" via package/, "Further sanity check: The rename_member method was provided only by the class(es) we expected";
}
