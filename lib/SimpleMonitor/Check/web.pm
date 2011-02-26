package SimpleMonitor::Check::web;
use base 'SimpleMonitor::Check';
use LWP::Simple;
use Time::HiRes qw/gettimeofday tv_interval/;

sub name { $_[0]->{name} || $_[0]->{url} }

sub check {
    my $self = shift;
    (warn "No URL given for check ".$self->name),return unless $self->{url};
    my $t0 = [gettimeofday];
    my $content = get($self->{url});
    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    $m = "Content returned in ${elapsed}s";
    if (!$content) { $self->fail }
    elsif ($self->{expect}) {
        $content =~ $self->{expect} ? $self->pass($m) : $self->warning($m); 
    } else { $self->pass($m) }
}

1;
