## no critic (RequireUseStrict, RequireUseWarnings, RequireTidyCode)
package PCR::Primer3;
## use critic

# ABSTRACT: Primer3 - object used to run Primer3

use namespace::autoclean;
use PCR::Primer;
use PCR::PrimerPair;
use Moose;

=method new

  Usage       : my $primer3_object = PCR::PrimerPair->new(
                    'cfg' => $config,
                );
  Purpose     : Constructor for creating Primer3 object
  Returns     : PCR::Primer3 object
  Parameters  : cfg     => HashRef
  Throws      : If parameters are not the correct type
  Comments    : None

=cut

sub new {
	my ($class, $cfg) = @_;
	return bless {'cfg' => $cfg}, $class;	
}

=method cfg

  Usage       : $primer->cfg;
  Purpose     : Getter/Setter for cfg attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      : 
  Comments    : 

=cut

sub cfg {
	my $self = shift;
	$self->{cfg} = shift if @_;
	return $self->{cfg};
}

=method setAmpInput

  Usage       : $primer->setAmpInput;
  Purpose     : Produce input file for Primer3 containing target sequences and settings
  Returns     : Name of Primer3 input file => Str
  Parameters  : AmpInfo             => ArrayRef [ Amp_ID, Sequence,
                                            Left_Primer_Seq, Right_Primer_Seq,
                                            [ Target, Length ],
                                            [ Excluded_Region_Start, Length ],
                                            [ Included_Region_Start, Length],
                                            Product_Product_Size_Range, ]
                Target Position     => Int
                Target Size         => Int
                Product Size Range  => Str
                Settings            => Int
                Design Round        => Int
                Output Directory    => Str
  Throws      : 
  Comments    : 

=cut

sub setAmpInput { #setAmpInput(@[id, seq], $target_position, $target_size, $product_size, $param_settings);
	#@amp=[id, seq, left_p_seq, right_p_seq,@targets[pos,length],@exluded[pos,length],(pos,length)]
	my $self = shift;
	my $ampinput = shift; # A ref to an Array of refs containing the ampid at 0 and the sequence at 1
	my $target_pos = shift;
	my $target_size = shift;
	my $product_size = shift;
	my $settings = shift;
	my $id = shift;
	my $out_dir = shift;
	my @params;
	#$id = $self->cfg->{'gene_id'} unless defined $id;
	my $file = $out_dir? "$out_dir/AmpForDesign_${id}_$settings.txt" : $self->cfg->{'exp-path'} . $self->cfg->{'tmp-path'}."AmpForDesign_$id"."_$settings.txt";
	open(OUTPUT, "> $file") or die "can't open $file: $!\n";
	foreach my $param (keys %{$self->cfg}) {
		my $key = $param;
		$param =~ s/^(\d)\_// if $param =~ m/PRIMER\_/;
		if ($1 && $1 eq $settings) {
			$param = $param . '=' . $self->cfg->{$key} . "\n";
			push(@params, $param) if $param =~ m/^PRIMER\_/;
		}
	}
	print OUTPUT join('', @params) if @params;
	foreach my $input (@{$ampinput}) {
		if (!defined $input->[7]) {
			print OUTPUT "PRIMER_PRODUCT_SIZE_RANGE=" . $product_size . "\n" if defined $product_size;
		} elsif (defined $product_size) {
			my ($start, $end) = split /-/, $product_size;
			print OUTPUT "PRIMER_PRODUCT_SIZE_RANGE=" . ($start + $input->[7]) . '-' . ($end + $input->[7]) . "\n";
		}
		print OUTPUT "PRIMER_SEQUENCE_ID=" . $input->[0] . "\n" if defined $input->[0];
		print OUTPUT "SEQUENCE=" . $input->[1] . "\n";
		print OUTPUT "PRIMER_LEFT_INPUT=" . $input->[2] ."\n" if defined $input->[2];
		print OUTPUT "PRIMER_RIGHT_INPUT=" . $input->[3] ."\n" if defined $input->[3];
		print OUTPUT "INCLUDED_REGION=" . $input->[6][0] . "," . $input->[6][1] . "\n" if defined $input->[6];
		
		if (defined $target_pos && defined $target_size) {
			print OUTPUT "TARGET=" . $target_pos . "," . $target_size . "\n" if defined $target_pos && defined $target_size;
		} elsif (defined $input->[4]) {
			foreach (@{$input->[4]}) {
				print OUTPUT "TARGET=" . $_->[0] . "," . $_->[1] . "\n";
			}
		}
		
		if (defined $input->[5]) {
			foreach (@{$input->[5]}) {
				print OUTPUT "EXCLUDED_REGION=" . $_->[0] . "," . $_->[1] . "\n";
			}
		}
		
		print OUTPUT "=\n";
	}
	close(OUTPUT);
	
	return $file;
}

=method primer3

  Usage       : $primer->primer3;
  Purpose     : Subroutine to run primer3
  Returns     : Primer Pairs        => ArrayRef of PCR::PrimerPair objects
  Parameters  : Primer3 Input File  => Str
                Primer3 Output File => Str
  Throws      : 
  Comments    : 

=cut

sub primer3 { # primer3($file);
	my $self = shift;
	my $file = shift;
	my $output = shift;
	my $pid = open(PRIMER, $self->cfg->{'Primer3-bin'} . " -strict_tags < $file |");
	my $results = [];
	my $record = 0;
	my $text;
	my $result = {};
	my $c = 0;
	my $nc = 0;
	my ($seq_id, $target, $ex_region, $explain_left, $explain_right, $explain_pair, $size_range);
	while (<PRIMER>) {
		$text .= $_;
		chomp;
		
		my $param = $_;
		if ($param =~ m/\_(\d+)\w*\=/) {
			$nc = $1;
			$param =~  s/\_(\d+)//;
		}
		
		if ($c ne $nc || $param =~ m/^\=$/) {
			$result->{PAIR}{amplicon_name} = $seq_id if defined $seq_id;
			$result->{PAIR}{target} = $target if defined $target;
			$result->{PAIR}{excluded_regions} = $ex_region if defined $ex_region && scalar(@$ex_region) > 0;
			$result->{LEFT}{explain} = $explain_left if defined $explain_left;
			$result->{RIGHT}{explain} = $explain_right if defined $explain_right;
			$result->{PAIR}{explain} = $explain_pair if defined $explain_pair;
			$result->{PAIR}{product_size_range} = $size_range if defined $size_range;
			$result->{LEFT}{sequence} = $result->{LEFT}{input} if !defined $result->{LEFT}{sequence};
			$result->{RIGHT}{sequence} = $result->{RIGHT}{input} if !defined $result->{RIGHT}{sequence};
			if ($record) {
				my $pair = PCR::PrimerPair->new($result->{PAIR});
				$pair->left_primer(PCR::Primer->new($result->{LEFT}));
				$pair->right_primer(PCR::Primer->new($result->{RIGHT}));
				push(@$results, $pair);
				$result = {};
			}
			$c = $nc;
			if ($param =~ m/^\=$/) {
				$record = 0;
				$ex_region = undef;
				$target = undef;
				$seq_id = undef;
				$explain_left = undef;
				$explain_right = undef;
				$explain_pair = undef;
				$size_range = undef;
			}
		} elsif ($param =~ m/SEQUENCE_ID\=(.+)/) {
				$seq_id = $1;
				$record = 1; 
		} elsif ($param =~ m/^SEQUENCE/) {
			$record = 1;
		}
		
		if ($param =~ m/PRIMER_PRODUCT_SIZE_RANGE\=(.+)/) {
			$size_range = $1;
		} elsif ($param =~ m/PRIMER\_(\w+)\_EXPLAIN\=(.+)/) {
			$explain_left = $2 if $1 eq "LEFT";
			$explain_right = $2 if $1 eq "RIGHT";
			$explain_pair = $2 if $1 eq "PAIR";
		} elsif ($param =~ m/^TARGET\=(.+)/ ) {
			$target = $1;
		} elsif ($param =~ m/^EXCLUDED_REGION\=(.+)/) {
			$ex_region = [] unless defined $ex_region;
			push(@$ex_region, $1);
		} elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param !~ m/INPUT/ && $param =~ m/^PRIMER_PRODUCT_SIZE\=(.+)$/) {
			$result->{PAIR}{product_size} = $1;
		} elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param !~ m/INPUT/ && $param =~ m/^PRIMER_WARNING\=(.+)$/) {
			$result->{PAIR}{warnings} = $1;
		} elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param =~ m/^PRIMER\_(LEFT|RIGHT|PAIR)\_*([\w\_]*)\=(.+)$/) {
			my ($p,$key,$value) = ($1,$2,$3);
			$key = $p."_".$key if $p eq "PAIR";
			if (!$key && defined $value) {
				my ($pos, $length) = split(",",$value);
				if (defined $pos && defined $length) {
					$result->{$p}{index_pos} = $p eq "LEFT"? $pos : $pos - $length + 1;
					$result->{$p}{length} = $length;
				}
			} else {
				$result->{$p}{lc($key)} = $value;
			}
		}
	}

	close(PRIMER);
	unlink $file;
	if (defined $output) {
		open(OUTPUT, ">> $output");
		print OUTPUT $text;
		close(OUTPUT);
	}
	return $results;
}

__PACKAGE__->meta->make_immutable;

1;

__END__