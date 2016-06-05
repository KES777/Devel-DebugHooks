use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
	module_name => 'Devel::DebugHooks',
	dist_author => 'Eugen Konkov <kes-kes@yandex.ru>',
	requires => {
		'Guard' =>  0,
	},
	recommends         => {
		'Log::Log4perl'   =>  0,            # Devel::DebugHooks::TraceAccess.pm
		'IO::Async::Loop' =>  0,            # bin/dclient.pl
	},
	test_requires      => {
		'Test::More'            =>  0,
		'Test::Output'          =>  0,
		'Test::Differences'     =>  0,
		'Data::Section::Simple' =>  0,
	},
	configure_requires => {
		'Module::Build'         =>  0,
	},
	license            => 'perl',
	create_makefile_pl => 'traditional',
	create_license     => 1,
	meta_merge         => {
		resources => {
			# Need help? Feel free to ask questions on:
			x_IRC => "irc://irc.perl.org/#debughooks",
		},
	},
);

$build->create_build_script;
