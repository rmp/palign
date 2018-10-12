package palign;
use strict;
use warnings;
use IO::File;
use File::Find;
use base qw(Exporter);
use DBI;
use DBD::SQLite;
use Carp;

our @EXPORT_OK = qw(readfa hash align attach detach report);
our $k         = 16;

my $ref_cache  = {};
my $hash_cache = {};
my $dbh;
$|++;

sub attach {
    my ($fn, $mode) = @_;
    $dbh = DBI->connect("dbi:SQLite:dbname=$fn","","",
			{
			    AutoCommit => 0,
			    RaiseError => 1,
#			    ReadOnly   => ($mode && $mode eq 'ro'),
			});

    if($mode ne 'ro') {
	$dbh->do(qq[CREATE TABLE IF NOT EXISTS hash (rowid integer primary key, subseq char(@{[$k]}) not null unique)]);
	$dbh->do(qq[CREATE TABLE IF NOT EXISTS reference (rowid integer primary key, seq_id char(64) not null unique)]);
	$dbh->do(qq[CREATE TABLE IF NOT EXISTS hash_ref (rowid integer primary key, id_hash bigint unsigned not null REFERENCES hash(rowid), id_reference bigint unsigned not null REFERENCES reference(rowid), start integer not null, unique(id_hash,id_reference,start))]);
    }
}

sub detach {
    $dbh->disconnect;
}

sub report {
    print <<"EOT";
references: @{[$dbh->selectall_arrayref(q[SELECT COUNT(*) FROM reference])->[0]->[0]]}
hashes:     @{[$dbh->selectall_arrayref(q[SELECT COUNT(*) FROM hash])->[0]->[0]]}
mappings:   @{[$dbh->selectall_arrayref(q[SELECT COUNT(*) FROM hash_ref])->[0]->[0]]}
EOT
}

sub readfa {
    my ($cb, @inputs) = @_;

    my $bytes = 0;
    my $finder = sub {
	my $fn = $_;
	if(!$fn || !-f $fn) {
	    return;
	}

	print "Reading $File::Find::name\n";
	my $io = IO::File->new($fn);
	my ($id, $seq);

	while(my $line = <$io>) {
	    $bytes += length $line;
	    chomp $line;
	    if($line =~ m{^>}smix) {
		#########
		# extend hashtable with the last-read sequence
		#
		if($id) {
		    $cb->($id, $seq);
		}
		
		($id) = $line =~ m{^>\s*(\S+)}smix;
		$seq = "";
		next;
	    }
	    $seq .= $line;
	}

	#########
	# extend hashtable with the final sequence
	#
	if($id) {
	    $cb->($id, $seq);
	}
	$io->close;
    };

    find($finder, @inputs);

    return $bytes;
}

my $caches_initialised;
sub _init_caches {
    $caches_initialised = 1;
    my $refs = $dbh->selectall_arrayref(q[SELECT rowid,seq_id FROM reference]);
    for my $ref (@{$refs}) {
	$ref_cache->{$ref->[1]} = $ref->[0];
    }

    my $hashes = $dbh->selectall_arrayref(q[SELECT rowid,subseq FROM hash]);
    for my $hash (@{$hashes}) {
	$hash_cache->{$hash->[1]} = $hash->[0];
    }

    return 1;
}

sub hash {
    my ($seq_id, $seq) = @_;

    $caches_initialised or _init_caches();

    my $count = 0;

    if(!$ref_cache->{$seq_id}) { # todo: timed expiry / keep cache at a given size
	$dbh->do(q[INSERT OR IGNORE INTO reference (seq_id) VALUES(?)], {}, $seq_id);
	$ref_cache->{$seq_id} = $dbh->selectall_arrayref(q[SELECT last_insert_rowid()])->[0]->[0];
    }

    for my $start (0..(length $seq)-$k) {
	my $subseq = substr $seq, $start, $k;

	if(!$hash_cache->{$subseq}) { # todo: timed expiry / keep cache at a given size
	    $dbh->do(q[INSERT OR IGNORE INTO hash (subseq) VALUES(?)], {}, $subseq);
	    $hash_cache->{$subseq} = $dbh->selectall_arrayref(q[SELECT last_insert_rowid()])->[0]->[0];
	}

	$dbh->do(q[INSERT OR IGNORE INTO hash_ref (id_hash, id_reference, start) VALUES(?,?,?)], {}, $hash_cache->{$subseq}, $ref_cache->{$seq_id}, $start);
	$count++;
    }

    $dbh->commit; # hit disk
    if($count) {
	print "  $seq_id $count mapped kmers\033[K\r";
    }
    return $count;
}

sub align {
    my ($id, $query) = @_;
    my $hits = {};

    my $hash_sth = $dbh->prepare(q[SELECT rowid FROM hash WHERE subseq=?]);
    my $hits_sth = $dbh->prepare(q[SELECT r.seq_id, h.start FROM hash_ref h, reference r WHERE h.id_hash=? AND r.rowid=h.id_reference]);
    for my $start (0..(length $query)-$k) {
	my $subseq = substr $query, $start, $k;

	$hash_sth->execute($subseq);
	my $result = $hash_sth->fetchrow_arrayref;
	if(!$result) {
	    next;
	}
	my $id_hash = $result->[0];

	$hits_sth->execute($id_hash);

	while (my $hit = $hits_sth->fetchrow_arrayref) {
	    my $hit_id    = $hit->[0];
	    my $hit_start = $hit->[1];
	    my $last_hit  = scalar @{$hits->{$hit_id}||[]} ? $hits->{$hit_id}->[-1] : undef;

	    if($last_hit && $start-1 == $last_hit->{query_end}-$k+1) {
		#########
		# extend hit for query
		#
		$last_hit->{query_end} ++;
		next;
	    }

	    push @{$hits->{$hit_id}}, {
		query_start => $start,
		query_end   => $start+$k-1,
		hit_start   => $hit_start,
	    };
	}
    }

    my $shorten = sub {
	my $str = shift;
	if(length $str > 16) {
	    $str = join q[..], (substr $str, 0, 6), (substr $str, -8, 8);
	}
	return $str;
    };

    for my $hit_id (keys %{$hits}) {
	my $refseq = recall($hit_id);
	printf ">%-16s                %s\n", $shorten->($hit_id), $refseq;

	for my $hit (@{$hits->{$hit_id}}) {
	    my $query_start = $hit->{query_start};
	    my $query_end   = $hit->{query_end};
	    my $hit_start   = $hit->{hit_start};

	    printf "+%-16s [%5d..%-5d] %s%s\n",
		$shorten->($id),
		$query_start, $query_end,
		" "x$hit_start,
		substr $query, $query_start, $query_end-$query_start+1;
	}
    }

    if(scalar keys %{$hits}) {
	print "\n";
    }
}

sub recall {
    my ($id) = @_;
    my $seq  = q[];
    my $pos  = 0;
    my $d;

    my $id_reference = $dbh->selectall_arrayref(q[SELECT rowid FROM reference WHERE seq_id=?], {}, $id)->[0]->[0];
    if(!$id_reference) {
	croak qq[could not find sequence $id_reference];
    }

    my $sth = $dbh->prepare(q[SELECT h.subseq FROM hash h, hash_ref hr WHERE hr.id_reference=? AND hr.start=? AND h.rowid=hr.id_hash]);
    while(1) {
	$sth->execute($id_reference, $pos);
	my $result = $sth->fetchrow_arrayref;
	if(!$result) {
	    last;
	}

	$seq .= $result->[0];

	if(!defined $d) {
	    $d = length $result->[0];
	}

	$pos += $d; # stride by the length of the sequence, not +1
    }

    my $final = $dbh->selectall_arrayref(q[SELECT hr.start,subseq FROM hash h, hash_ref hr WHERE hr.id_reference=? AND h.rowid=hr.id_hash AND hr.start=(SELECT MAX(start) FROM hash_ref hr2 WHERE id_reference=?);], {}, $id_reference, $id_reference);
    my $start = $final->[0]->[0];
    my $subseq = $final->[0]->[1];
    substr $seq, $start, $k, $subseq; # splice in the remaining piece
    return $seq;
}
1;
