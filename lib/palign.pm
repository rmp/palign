package palign;
use strict;
use warnings;
use IO::File;
use base qw(Exporter);

our @EXPORT_OK = qw(readfa hash align);
our $k = 16;
our $hashtable = {_sequences => {}};

sub readfa {
    my ($cb, @files) = @_;

    my $bytes = 0;
    for my $fn (@files) {
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
		    $hashtable->{_sequences}->{$id} = $seq; # note conflict across files/sequences
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
	$hashtable->{_sequences}->{$id} = $seq; # note conflict across files/sequences
	$cb->($id, $seq);
	$io->close;
    }
    return $bytes;
}

sub hash {
    my ($id, $seq) = @_;

    for my $start (0..(length $seq)-$k) {
	my $subseq = substr $seq, $start, $k;
	if(!exists $hashtable->{$subseq}) {
	    $hashtable->{$subseq} = [];
	}
	push @{$hashtable->{$subseq}}, { id => $id, start => $start };
    }
}

sub align {
    my ($id, $seq) = @_;

    my $hits = {};

    for my $start (0..(length $seq)-$k) {
	my $subseq = substr $seq, $start, $k;

	for my $hit (@{$hashtable->{$subseq}||[]}) {
	    my $hit_id    = $hit->{id};
	    my $hit_start = $hit->{start};
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

    for my $hit_id (keys %{$hits}) {
	printf ">%-16s                %s\n", $hit_id, $hashtable->{_sequences}->{$hit_id};
	for my $hit (@{$hits->{$hit_id}}) {
	    my $query_start = $hit->{query_start};
	    my $query_end   = $hit->{query_end};
	    my $hit_start   = $hit->{hit_start};

	    printf "+%-16s [%5d..%-5d] %s%s\n",
		$id,
		$query_start, $query_end,
		" "x$hit_start,
		substr $hashtable->{_sequences}->{$id}, $query_start, $query_end-$query_start+1;
	}
    }
    print "\n";
}

1;
