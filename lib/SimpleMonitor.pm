package SimpleMonitor;
use Net::Domain qw/hostfqdn/;
use SimpleMonitor::Check;
use Email::Send;
use Carp qw/croak/;
use UNIVERSAL::require;
use JSON::XS;
use File::Slurp;
use DBI;

our %config = (
    notify_every => 60*60,
    mailto => "root\@localhost",
    mailfrom => "The SimpleMonitor system <".getpwuid($>)."\@".hostfqdn.">",
    database => "/etc/simplemonitor/results.db"
);

sub _get_json {
    my $filename = shift;
    die "Can't read config file $filename" unless -r $filename;
    my $c = read_file($filename);
    my $read_conf = eval { decode_json($c) };
    die "Configuration file $filename has incorrect syntax: $@" if $@;
    return $read_conf;
}

sub load_config {
    # XXX getopt
    for (".", "/etc/simplemonitor") {
        my $fn = "$_/simplemonitor.conf";
        if (-f $fn) {
            %config = (%config, %{ _get_json($fn) });
            last;
        }
    }
    $config->{checks} = [ 
        ref $config->{checksfile} eq "ARRAY" ? 
            map { @{_get_json($_)} } @{$config->{checksfile}}
        : $config->{checksfile} ?
            @{_get_json($config->{checksfile})}
        : -f "./checks.conf" ? @{_get_json("./checks.conf") }
        : @{_get_json("/etc/simplemonitor/checks.conf") }
    ];
    checks_config_helper();
    setup_database()
}

sub checks_config_helper {
    # Make some common cases easier, and ensure the file makes sense
    for (@{$config->{checks}})  {
        bless $_, "SimpleMonitor::Check";

        $_->{type} ||= "web" if $_->{url};
        # XXX More here as we go along

        if (!$_->{type}) { croak "No type given for check ".$_->name }
        my $class = "SimpleMonitor::Check::".$_->{type};
        $class->require or die "Can't load monitor class for $_->{type}: $@";
        $_ = $class->new($_);
    }
}

sub setup_database {
    my $creating = !-f $config{database};
    $config{dbh} = DBI->connect("dbi:SQLite:$config{database}")
        or die "Can't connect to database: ".DBI->errstr;
    if ($creating) { while (<DATA>) { $config{dbh}->do($_) } }
}

sub run_checks {  $_->check for @{$config->{checks}} }

sub record {
    my ($self, %details) = @_;
    my $c = $details{check};
    if ($details{status} ne "pass") {
        # Get last notified time
        my $previous = $config{dbh}->selectall_arrayref("SELECT lastnotified,result FROM
            warnings WHERE checkjson = ?", { Slice => {} }, $c->code);
        my $notified;
        my $will_notify;
        if ($previous and $previous->[0]) {
            $notified = $previous->[0]{lastnotified};
            $will_notify = 1 if (time - $notified) > $c->notify_every;
        } else { $will_notify = 1; }
        if ($will_notify) {
            # Notify
            $self->notify(%details);
            $notified = time;
        }
        $config{dbh}->do("DELETE FROM warnings WHERE checkjson = ?",undef, $c->code);
        $config{dbh}->do("INSERT INTO warnings VALUES (?,?,?,?,?,?,?)",undef,
            $c->code, $c->name, $c->{system}, time(), $details{status}, $details{message}, $notified);
        
    }
    $config{dbh}->do("DELETE FROM latest WHERE checkjson = ?",undef, $c->code);
    $config{dbh}->do("INSERT INTO latest VALUES (?,?,?,?,?,?)",undef,
        $c->code, $c->name, $c->{system}, time(), $details{status}, $details{message});
    print $details{status}.": ".$c->name.": ".$details{message}."\n" 
        if -t STDOUT;
}

sub notify {
    my ($self, %details) = @_;
    my $to = $details{check}->{mailto} || $config{mailto}
    Email::Send->new->send(<<EOF);
From: $config{mailfrom}
To: $config{mailto}
Subject: SimpleMonitor $details{status} - @{[ $details{check}->name ]}

$details{message}

EOF
}

sub status_for_template { ( 
    latest => $config{dbh}->selectall_arrayref("SELECT * FROM latest
    ORDER BY system",{ Slice => {} }),
    warnings => $config{dbh}->selectall_arrayref("SELECT * FROM warnings
    ORDER BY system", { Slice => {} })
) }

__DATA__
CREATE TABLE latest (checkjson, name, system, checked, result, message);
CREATE TABLE warnings (checkjson, name, system, checked, result, message, lastnotified);
