package MyCPAN::App::DPAN;
use strict;
use warnings;

use base qw(MyCPAN::App::BackPAN::Indexer);
use vars qw($VERSION $logger);

use Cwd qw(cwd);
use File::Spec::Functions;
use Log::Log4perl;

$VERSION = '1.28_07';

BEGIN {

$SIG{INT} = sub { exit };

my $cwd = cwd();

my $report_dir = catfile( $cwd, 'indexer_reports' );

my %Defaults = (
    author_map                  => undef,
	dpan_dir                    => $cwd,
	collator_class              => 'MyCPAN::App::DPAN::Reporter::Minimal',
	dispatcher_class            => 'MyCPAN::Indexer::Dispatcher::Serial',
	extra_reports_dir           => undef,
	fresh_start                 => defined $ENV{DPAN_FRESH_START} ? $ENV{DPAN_FRESH_START} : 0,
	i_ignore_errors_at_my_peril => 0,
	ignore_missing_dists        => 0,
	ignore_packages             => 'main MY MM DB bytes DynaLoader',
	indexer_class               => 'MyCPAN::App::DPAN::Indexer',
	organize_dists              => 1,
	parallel_jobs               => 1,
	pause_id                    => 'DPAN',
	pause_full_name             => "DPAN user <CENSORED>",
	queue_class                 => 'MyCPAN::App::DPAN::SkipQueue',
	relative_paths_in_report    => 1,
	reporter_class              => 'MyCPAN::App::DPAN::Reporter::Minimal',
	skip_perl                   => 0,
	use_real_whois              => 0,
	);

sub default_keys
	{
	my %Seen;
	grep { ! $Seen{$_}++ } keys %Defaults, $_[0]->SUPER::default_keys;
	}

sub default
	{
	exists $Defaults{ $_[1] }
		?
	$Defaults{ $_[1] }
		:
	$_[0]->SUPER::default( $_[1] );
	}

sub adjust_config
	{
	my( $application ) = @_;

	my $coordinator = $application->get_coordinator;
	my $config      = $coordinator->get_config;

	# the Indexer stuff expects the directory in backpan_dir
	if( $config->exists( 'dpan_dir') )
		{
		$config->set( 
			'backpan_dir', 
			$config->get( 'dpan_dir' )
			);
		}

	
	
	$application->SUPER::adjust_config;
	}

$logger = Log::Log4perl->get_logger( 'backpan_indexer' );
}

sub activate_steps
	{
	qw(
	process_options
	setup_coordinator
	setup_environment
	handle_config
	setup_logging
	fresh_start
	setup_dirs
	run_components
	);
	}

sub activate_end
	{
	my( $application ) = @_;

	print <<"HERE";
=================================================
Ensure you reload your indices in your CPAN tool!

For CPAN.pm, use:

	cpan> reload index
    
For CPANPLUS, use

	CPAN Terminal> x
=================================================
HERE

	$application->SUPER::activate_end;
	}

sub components
	{
	(
	[ qw( queue      MyCPAN::Indexer::Queue                get_queue      ) ],
	[ qw( dispatcher MyCPAN::Indexer::Dispatcher::Serial   get_dispatcher ) ],
	[ qw( reporter   MyCPAN::App::DPAN::Reporter::Minimal  get_reporter   ) ],
	[ qw( worker     MyCPAN::Indexer::Worker               get_task       ) ],
	[ qw( collator   MyCPAN::App::DPAN::Reporter::Minimal  get_collator   ) ],
	[ qw( interface  MyCPAN::Indexer::Interface::Text      do_interface   ) ],
	)
	}

sub fresh_start
	{
	my( $application ) = @_;

	return unless $application->get_coordinator->get_config->fresh_start;

	my $indexer_reports_dir = $application->get_coordinator->get_config->report_dir;

	require File::Path;

	File::Path::remove_tree( $indexer_reports_dir );

	return 1;
	}

1;

=head1 NAME

MyCPAN::App::DPAN - Create a CPAN-like structure out of some dists

=head1 SYNOPSIS

	use MyCPAN::App::DPAN;

	my $application = MyCPAN::App::DPAN->activate( @ARGV );

	# do some other stuff, anything that you like

	$application->activate_end;

=head1 DESCRIPTION

This module ties together all the bits to let the C<dpan> do its work. It
overrides the defaults in C<MyCPAN::App::BackPAN::Indexer> to provide the
right components.

The work happens in two steps. When you call C<activate>, the program goes
through all of the steps to examin each of the module distributions. It creates
a report for each distribution, then stops. This pause right after the
examination gives you the chance to do something right before the program
creates the PAUSE index files. The examination might take several minutes
(or even hours depending on how much you want to index), so you have a chance
to check the state of the world before the next step.

When you call C<activate_end>, the program takes the results from the
previous step and creates the PAUSE index files in the F<modules> directory.
This step should be very quick since all of the information is ready-to-go.

=cut

=head1 SOURCE AVAILABILITY

This code is in Github:

      git://github.com/briandfoy/mycpan-indexer.git
      git://github.com/briandfoy/mycpan--app--dpan.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008-2010, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut
