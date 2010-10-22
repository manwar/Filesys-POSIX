package Filesys::POSIX::Extensions;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;
use Filesys::POSIX::Real::Inode;
use Filesys::POSIX::Real::Dirent;

sub EXPORT {
    qw/map alias/;
}

sub map {
    my ($self, $real_src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);
    my $name = $hier->basename;
    my $parent = $self->stat($hier->dirname);

    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('File exists') if $parent->{'dirent'}->exists($name);

    my $node = Filesys::POSIX::Real::Inode->new($real_src,
        'dev'       => $parent->{'dev'},
        'parent'    => $parent
    );

    $parent->{'dirent'}->set($name, $node);
}

sub alias {
    my ($self, $src, $dest) = @_;
    my $hier = Filesys::POSIX::Path->new($dest);                                                                            my $name = $hier->basename;
    my $node = $self->stat($src);                                                                                           my $parent = $self->stat($hier->dirname);

    die('Is a directory') if ($node->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;
    die('File exists') if $parent->{'dirent'}->exists($name);

    $parent->{'dirent'}->set($name, $node);
}

1;