use inc::Module::Install;
name        'SimpleMonitor';
abstract    'The simplest host monitoring software that can possibly work';
author      'Simon Cozens <simon@simon-cozens.org>';
include     'Module::AutoInstall';
license     'artistic';
perl_version '5.006';
all_from    "lib/SimpleMonitor.pm",
requires	"Plack" => 0.9017;
requires	"Plack::Request" => 0;
requires	"File::Slurp" => 0;
requires	"DBI" => 0;
requires	"DBD::SQLite" => 1.27;
requires	"Template" => 0;
requires    "Time::HiRes" => 0;
requires    "Email::Send" => 0;
requires    "LWP::Simple" => 0;
requires    "JSON::XS" => 0;
requires    "Net::Ping::External" => 0;

auto_install;
WriteAll;
