package Tickit::Widget::LogAny;
# ABSTRACT: 
use strict;
use warnings;

use parent qw(Tickit::ContainerWidget);
# Tickit::Widget::VBox

our $VERSION = '0.001';

=head1 NAME

Tickit::Widget::LogAny -

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Any::Adapter::Tickit;

use Variable::Disposition qw(retain_future);
use Tickit::Widget::Table;
use POSIX qw(strftime);

use constant DEFAULT_LINES => 5;
use constant CLEAR_BEFORE_RENDER => 0;
use constant WIDGET_PEN_FROM_STYLE => 1;
use Tickit::Style;
BEGIN {
	style_definition base => ;
}

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
		splice => sub {
			my ($ev, $idx, $len, $data, $spliced) = @_;
			return unless $self->max_entries;
			retain_future(
				$log_storage->count->then(sub {
					my ($rows) = @_;
					my $len = $rows - $self->max_entries;
					return Future->done if $len <= 0;
					$log_storage->splice(
						0, $len, []
					)
				})
			)
		}
	);
	$self->{log_storage} = $log_storage;
	$self->{lines} = $lines if $lines;
	$self->{scroll} = $scroll;
	$self->{log} = [];

	$self->{table} = Tickit::Widget::Table->new(
		adapter => $self->log_storage,
		failure_transformations => [
			sub { '' }
		],
		columns => [ {
			label => 'Timestamp',
			width => 23,
			transform => sub {
				my ($row, $col, $cell) = @_;
				Future->done(
					String::Tagged->new(
						sprintf '%s.%03d', strftime('%Y-%m-%d %H:%M:%S', localtime $cell), 1000 * ($cell - int($cell))
					)
					->apply_tag( 0, 4, fg => 4)
					->apply_tag( 5, 2, fg => 4)
					->apply_tag( 8, 2, fg => 4)
					->apply_tag(11, 2, fg => 2)
					->apply_tag(14, 2, fg => 2)
					->apply_tag(17, 2, fg => 2)
					->apply_tag(20, 3, fg => 2)
				)
			}
		}, {
			label => 'Severity',
			width => 9
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
#	if($io_async) {
#		require IO::Async::Notifier;
#		open $IO::Async::Notifier::DEBUG_FD, '>', \my $str or die $!;
#
#	}
	$self;
}

sub max_entries { shift->{max_entries} }
sub log_storage { shift->{log_storage} }

sub window_gained {
	my ($self, $win) = @_;
	$self->SUPER::window_gained($win);
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
}

=head2 reshape

Override parent L<Tickit::Widget/reshape> method to update our internal line count.

=cut

# TODO - why do this? can't we just check $self->window->lines when we need it.
# caching the value if necessary...?
sub reshape {
	my $self = shift;
	if(my $win = $self->window) {
		$self->{lines} = $win->lines;
	}
	return $self->SUPER::reshape(@_);
}

1;

__END__

=head1 SEE ALSO

=head1 AUTHOR

Tom Molesworth <cpan@perlsite.co.uk>

=head1 LICENSE

Copyright Tom Molesworth 2015. Licensed under the same terms as Perl itself.

