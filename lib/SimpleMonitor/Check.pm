package SimpleMonitor::Check;
use JSON::XS;
sub code { encode_json({%{$_[0]}}) }
sub name { $_[0]->{name} || $_->code }
sub defaults {} 
sub new { my ($class, $data) = @_;
   bless {$class->defaults, %$data}, $class;
}
sub notify_every { $_[0]->{notify_every} || $SimpleMonitor::config{notify_every} }

for my $s (qw(pass fail warning)) { 
    *$s = sub { SimpleMonitor->record( status => $s, check => $_[0],
    message => $_[1]); }
}
1;
