package Log::Any::Adapter::Tickit;

use strict;
use warnings;

use parent qw(Log::Any::Adapter::Base);

=head1 NAME

Log::Any::Adapter::Tickit - Simple adapter for L<Tickit> logging from L<Log::Any>

=head1 SYNOPSIS

TBD

=head1 DESCRIPTION

The C<log_level> attribute may be set to define a minimum level to log.

=cut

use Adapter::Async::OrderedList::Array;
use Time::HiRes;
use Log::Any::Adapter::Util ();

my $trace_level = Log::Any::Adapter::Util::numeric_level('trace');

sub init {
    my ($self) = @_;
    if ( exists $self->{log_level} ) {
        $self->{log_level} = Log::Any::Adapter::Util::numeric_level( $self->{log_level} )
          unless $self->{log_level} =~ /^\d+$/;
    }
    else {
        $self->{log_level} = $trace_level;
    }
}

sub adapter { shift->{adapter} //= Adapter::Async::OrderedList::Array->new }

foreach my $method ( Log::Any::Adapter::Util::logging_methods() ) {
    no strict 'refs';
    my $method_level = Log::Any::Adapter::Util::numeric_level($method);
    *{$method} = sub {
        my ( $self, $text ) = @_;
        return if $method_level > $self->{log_level};
		$self->adapter->push([ {
			severity  => $method,
			message   => $text,
			category  => $self->{category},
			timestamp => Time::HiRes::time,
		} ]);
    };
}

foreach my $method ( Log::Any::Adapter::Util::detection_methods() ) {
    no strict 'refs';
    my $base = substr( $method, 3 );
    my $method_level = Log::Any::Adapter::Util::numeric_level($base);
    *{$method} = sub {
        return !!( $method_level <= $_[0]->{log_level} );
    };
}

1;

__END__

