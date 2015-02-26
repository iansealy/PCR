#!/usr/bin/env perl
# primer_pair.t
use warnings; use strict;

use Test::More;
use Test::Exception;
use Test::MockObject;

plan tests => 1 + 17 + 2;

use PCR::PrimerPair;

# make 2 mock Primer objects
my $mock_l_primer = Test::MockObject->new();
#$mock_l_primer->mock('seq_region', sub { return '5'} );
#$mock_l_primer->mock('seq_region_start', sub { return 2403050 } );
#$mock_l_primer->mock('seq_region_end', sub { return 2403073 } );
#$mock_l_primer->mock('seq_region_strand', sub { return '1' } );
#$mock_l_primer->mock('sequence', sub { return 'ACGATGACAGATAGACAGAAGTCG' } );
$mock_l_primer->mock('primer_summary', sub { return ( '5:2403050-2403073:1', 'ACGATGACAGATAGACAGAAGTCG' ) } );
$mock_l_primer->mock('primer_info', sub { return ( '5:2403050-2403073:1', 'AGATAGACTAGACATTCAGATCAG', 24, 58.23, 45.5 ) } );
$mock_l_primer->set_isa('PCR::Primer');

my $mock_r_primer = Test::MockObject->new();
#$mock_r_primer->mock('seq_region', sub { return '5'} );
#$mock_r_primer->mock('seq_region_start', sub { return 2403250 } );
#$mock_r_primer->mock('seq_region_end', sub { return 2403273 } );
#$mock_r_primer->mock('seq_region_strand', sub { return '-1' } );
#$mock_r_primer->mock('sequence', sub { return 'AGATAGACTAGACATTCAGATCAG' } );
$mock_r_primer->mock('primer_summary', sub { return ( '5:2403050-2403273:-1', 'AGATAGACTAGACATTCAGATCAG' ) } );
$mock_r_primer->mock('primer_info', sub { return ( '5:2403050-2403273:-1', 'AGATAGACTAGACATTCAGATCAG', 24, 58.23, 45.5 ) } );
$mock_r_primer->set_isa('PCR::Primer');

# make a new primer object
my $primer_pair = PCR::PrimerPair->new(
    amplicon_name => 'ENSDARE00000001',
    pair_name => '5:2403050-2403273',
    product_size => '224',
    left_primer => $mock_l_primer,
    right_primer => $mock_r_primer,
);

# 1 test
isa_ok( $primer_pair, 'PCR::PrimerPair');

# test methods - 17 tests
my @methods = qw(  pair_name amplicon_name warnings target explain
    product_size_range excluded_regions product_size query_slice_start query_slice_end
    left_primer right_primer pair_compl_end pair_compl_any pair_penalty
    primer_pair_summary primer_pair_info
);

foreach my $method ( @methods ) {
    can_ok( $primer_pair, $method );
}

# check summary and info methods - 2 tests
is( join(",", $primer_pair->primer_pair_summary),
    'ENSDARE00000001,224,5:2403050-2403073:1,ACGATGACAGATAGACAGAAGTCG,5:2403050-2403273:-1,AGATAGACTAGACATTCAGATCAG',
    'check primer primer_summary' );

is( join(",", $primer_pair->primer_pair_info),
   'ENSDARE00000001,5:2403050-2403273,224,5:2403050-2403073:1,AGATAGACTAGACATTCAGATCAG,24,58.23,45.5,5:2403050-2403273:-1,AGATAGACTAGACATTCAGATCAG,24,58.23,45.5',
   'check primer_pair_info' );


