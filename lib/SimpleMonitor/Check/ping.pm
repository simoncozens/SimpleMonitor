package SimpleMonitor::Check::ping;
use base 'SimpleMonitor::Check';
use Net::Ping;
use Time::HiRes qw/gettimeofday tv_interval/;

sub defaults { maximum => 5, warn => 3 }

sub name { $_[0]->{system}." ping" }
my $p = Net::Ping->new("external");
$p->hires();

sub check {
    my $self = shift;
    (warn "No system given for check ".$self->name),return 
        unless $self->{system};
    my ($success, $time) = $p->ping($self->{system}, $self->{maximum});
    if ($success) {
        my $m = "Ping reply in ${time}s";
        if ($time > $self->{warn}) { $self->warning($m) } else { $self->pass($m) }
    } else { $self->fail("Ping timeout (>".$self->{maximum}."s)") }
}

1;
