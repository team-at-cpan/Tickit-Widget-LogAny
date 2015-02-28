package Tickit::Widget::LogAny;
# ABSTRACT: display log output in a Tickit window
use strict;
use warnings;

use parent qw(Tickit::ContainerWidget);

our $VERSION = '0.001';

=head1 NAME

Tickit::Widget::LogAny - log message rendering

=head1 SYNOPSIS

# EXAMPLE: examples/synopsis.pl

=head1 DESCRIPTION

Provides basic log rendering, with optional warn() / STDERR capture.

=cut

use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Any::Adapter::Tickit;
use Log::Any::Adapter::Util ();

use Variable::Disposition qw(retain_future);
use POSIX qw(strftime);

use Tickit::Style;
use Tickit::Widget::Table;

use constant DEFAULT_LINES => 5;
use constant WIDGET_PEN_FROM_STYLE => 1;

BEGIN {
	style_definition base =>
		date_fg               => 'white',
		date_sep_fg           => 'white',
		time_fg               => 6,
		time_sep_fg           => 'white',
		ms_fg                 => 6,
		ms_sep_fg             => 'white',
        severity_emergency_fg => 'hi-red',
        severity_alert_fg     => 'hi-red',
        severity_critical_fg  => 'hi-red',
        severity_error_fg     => 'hi-red',
        severity_warning_fg   => 'red',
        severity_notice_fg    => 'green',
        severity_info_fg      => 'green',
        severity_debug_fg     => 'grey',
        severity_trace_fg     => 'grey',
		;
}

=head1 METHODS

=cut

sub lines { shift->{lines} || DEFAULT_LINES }
sub cols  { 1 }

=head2 new

Takes the following named parameters:

=over 4

=item * lines - maximum number of lines to store and display, defaults to DEFAULT_LINES (5)

=item * warn - if true, will install a handler for warn()

=item * scroll - if true (default), will attempt to scroll the window on new entries

=back

=cut

sub new {
	my $class = shift;
	my %args = @_;
	my $log_storage = Adapter::Async::OrderedList::Array->new;
	Log::Any::Adapter->set('Tickit', adapter => $log_storage);

	my $max_entries = delete($args{max_entries}) // 5000;
	my $io_async = delete $args{io_async};
	my $lines = delete $args{lines};
	my $warn = delete $args{warn};
	my $stderr = delete $args{stderr};
	my $scroll = exists $args{scroll} ? delete $args{scroll} : 1;
	my $self = $class->SUPER::new(%args);
	$log_storage->bus->subscribe_to_event(
		splice => $self->curry::weak::on_splice,
	);
	$self->{log_storage} = $log_storage;
	$self->{lines} = $lines if $lines;
	$self->{scroll} = $scroll;
	$self->{log} = [];

	$self->{table} = Tickit::Widget::Table->new(
		class   => 'log_entries',
		adapter => $self->log_storage,
		failure_transformations => [
			sub { '' }
		],
		columns => [ {
			label => 'Timestamp',
			width => 23,
			transform => sub {
				my ($row, $col, $cell) = @_;
				my @date = $self->get_style_pen('date')->getattrs;
				my @date_sep = $self->get_style_pen('date_sep')->getattrs;
				my @time = $self->get_style_pen('time')->getattrs;
				my @time_sep = $self->get_style_pen('time_sep')->getattrs;
				my @ms = $self->get_style_pen('ms')->getattrs;
				my @ms_sep = $self->get_style_pen('ms_sep')->getattrs;
				Future->done(
					String::Tagged->new(
						sprintf '%s.%03d', strftime('%Y-%m-%d %H:%M:%S', localtime $cell), 1000 * ($cell - int($cell))
					)
					->apply_tag( 0, 4, @date)
					->apply_tag( 4, 1, @date_sep)
					->apply_tag( 5, 2, @date)
					->apply_tag( 7, 1, @date_sep)
					->apply_tag( 8, 2, @date)
					->apply_tag(11, 2, @time)
					->apply_tag(13, 1, @time_sep)
					->apply_tag(14, 2, @time)
					->apply_tag(16, 1, @time_sep)
					->apply_tag(17, 2, @time)
					->apply_tag(19, 1, @ms_sep)
					->apply_tag(20, 3, @ms)
				)
			}
		}, {
			label => 'Severity',
			width => 9,
			transform => sub {
				my ($row, $col, $cell) = @_;
				$self->{severity_style}{$cell}
			}
		}, {
			label => 'Category',
			width => 24
		}, {
			label => 'Message'
		} ],
		item_transformations => [
			sub {
				my ($idx, $item) = @_;
				Future->done([ map $_ // '', @{$item}{qw(timestamp severity category message)} ])
			}
		]
	);
	$log->debug("Created table");

	# Take over warn statements if requested
	$SIG{__WARN__} = sub {
		my ($txt) = @_;
		s/\v+//g for $txt;
		$log->warn($txt)
	} if $warn;

	if($stderr) {
		require Tie::Tickit::LogAny::STDERR;
		tie *STDERR, 'Tie::Tickit::LogAny::STDERR';
	}

	# Just handled via STDERR for now
#	if($io_async) {
#		require IO::Async::Notifier;
#		open $IO::Async::Notifier::DEBUG_FD, '>', \my $str or die $!;
#
#	}
	$self;
}

sub update_severity_styles {
	my ($self) = @_;
	my %severity;
	for my $severity (Log::Any::Adapter::Util::logging_methods) {
		my @style = $self->get_style_pen('severity_' . $severity)->getattrs;
		die "Bad style - $severity ($@)" unless @style;
		$severity{$severity} = 
			Future->done(
				String::Tagged->new(
					$severity
				)
				->apply_tag( 0, -1, @style)
			);
	}
	$self->{severity_style} = \%severity;
	$self
}

sub on_splice {
	my ($self, $ev, $idx, $len, $data, $spliced) = @_;
	return unless $self->max_entries;
	retain_future(
		$self->log_storage->count->then(sub {
			my ($rows) = @_;
			my $len = $rows - $self->max_entries;
			return Future->done if $len <= 0;
			$self->log_storage->splice(
				0, $len, []
			)
		})
	)
}

sub max_entries { shift->{max_entries} }
sub log_storage { shift->{log_storage} }

sub window_gained {
	my ($self, $win) = @_;
	$self->SUPER::window_gained($win);
	$self->update_severity_styles;
	my $child = $win->make_sub(
		1, 0, $win->lines, $win->cols
	);
	$self->{table}->set_window($child);
}

sub children { shift->{table} }

=head2 render_to_rb


=cut

sub render_to_rb {
	my ($self, $rb, $rect) = @_;
	my $win = $self->window or return;
	$rb->clear;
	$rb->text_at(0,0, "Level: all   Category: all   Filter: ", $self->get_style_pen);
}

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Log::Any>

=item * L<Log::Any::Adapter::Tickit>

=item * L<Tie::Tickit::STDERR>

=back

=head1 AUTHOR

Tom Molesworth <cpan@perlsite.co.uk>

=head1 LICENSE

Copyright Tom Molesworth 2014-2015. Licensed under the same terms as Perl itself.

