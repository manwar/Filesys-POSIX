package Filesys::POSIX::Real::Directory;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Directory ();

use Errno qw/ENOENT/;
use Carp qw/confess/;

our @ISA = qw/Filesys::POSIX::Directory/;

sub new {
    my ($class, $path, $inode) = @_;

    return bless {
        'path'      => $path,
        'node'      => $inode,
        'mtime'     => 0,
        'overlays'  => {},
        'skipped'   => {},
        'members'   => {
            '.'     => $inode,
            '..'    => $inode->{'parent'}? $inode->{'parent'}: $inode
        }
    }, $class;
}

sub _sync_all {
    my ($self) = @_;
    my $mtime = (lstat $self->{'path'})[9] or confess $!;

    return unless $mtime > $self->{'mtime'};

    $self->open;

    while (my $item = $self->read) {
        $self->_sync_member($item);
    }

    $self->close;

    $self->{'mtime'} = $mtime;
}

sub _sync_member {
    my ($self, $name) = @_;
    my $subpath = "$self->{'path'}/$name";
    my @st = lstat $subpath;

    if (scalar @st == 0 && $!{'ENOENT'}) {
        delete $self->{'members'}->{$name};
        return;
    }

    confess $! unless @st;

    if (exists $self->{'members'}->{$name}) {
        $self->{'members'}->{$name}->update(@st);
    } else {
        $self->{'members'}->{$name} = Filesys::POSIX::Real::Inode->new($subpath,
            'st_info'   => \@st,
            'dev'       => $self->{'node'}->{'dev'},
            'parent'    => $self->{'node'}
        );
    }
}

sub get {
    my ($self, $name) = @_;
    return $self->{'overlays'}->{$name} if exists $self->{'overlays'}->{$name};

    $self->_sync_member($name) unless exists $self->{'members'}->{$name};
    return $self->{'members'}->{$name};
}

sub set {
    my ($self, $name, $inode) = @_;
    $self->{'overlays'}->{$name} = $inode;
}

sub exists {
    my ($self, $name) = @_;
    return 1 if exists $self->{'overlays'}->{$name};

    $self->_sync_member($name);
    return exists $self->{'members'}->{$name};
}

sub delete {
    my ($self, $name) = @_;

    if (exists $self->{'overlays'}->{$name}) {
        delete $self->{'overlays'}->{$name};
        return;
    }

    my $member = $self->{'members'}->{$name} or return;
    my $subpath = "$self->{'path'}/$name";

    if ($member->dir) {
        rmdir($subpath);
    } else {
        unlink($subpath);
    }

    if ($!) {
        confess $! unless $!{'ENOENT'};
    }

    my $now = time;
    @{$self->{'node'}}{qw/mtime ctime/} = ($now, $now);

    delete $self->{'members'}->{$name};
}

sub detach {
    my ($self, $name) = @_;

    if (exists $self->{'overlays'}->{$name}) {
        delete $self->{'overlays'}->{$name};
        return;
    }

    if (exists $self->{'members'}->{$name}) {
        delete $self->{'overlays'}->{$name};
    }
}

sub list {
    my ($self, $name) = @_;
    $self->_sync_all;

    my %union = (
        %{$self->{'members'}},
        %{$self->{'overlays'}}
    );

    return keys %union;
}

sub count {
    scalar(shift->list);
}

sub open {
    my ($self) = @_;

    @{$self->{'skipped'}}{keys %{$self->{'overlays'}}} = values %{$self->{'overlays'}};

    $self->close;
    opendir($self->{'dh'}, $self->{'path'}) or confess($!);
}

sub rewind {
    my ($self) = @_;

    @{$self->{'skipped'}}{keys %{$self->{'overlays'}}} = values %{$self->{'overlays'}};

    if ($self->{'dh'}) {
        rewinddir $self->{'dh'};
    }
}

sub read {
    my ($self) = @_;
    my $item;

    if ($self->{'dh'}) {
        $item = readdir $self->{'dh'};
    }

    if ($item) {
        delete $self->{'skipped'}->{$item};
    } else {
        $item = each %{$self->{'skipped'}};
    }

    return $item;
}

sub close {
    my ($self) = @_;

    if ($self->{'dh'}) {
        closedir $self->{'dh'};
        delete $self->{'dh'};
    }
}

1;