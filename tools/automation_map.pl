#!/usr/bin/perl
## Builds docs/automation_map.html: a flow map (triggers -> automations -> scripts -> destinations)
## from automation/*.yaml, scripts/*.yaml and the custom blueprints. Regenerate after editing:
##   perl tools/automation_map.pl
## No YAML parser is installed here, so this reads the files by indentation. It relies on the
## conventions in this repo (top-level list items, keys at 2-space indent, literal service names).
use strict;
use warnings;
use JSON::PP;
use File::Basename;
use FindBin qw($Bin);

my $root = "$Bin/..";
chdir $root or die "chdir: $!";

sub slurp { open my $fh, '<', $_[0] or die "$_[0]: $!"; local $/; my $t = <$fh>; return $t }
sub unq { my $s = shift // ''; $s =~ s/^\s+|\s+$//g; $s =~ s/^(["'])(.*)\1$/$2/; return $s }

## Phones / destinations
my %PHONE = (jeff => 'phone_jeff', jen => 'phone_jen');
my %DEST = (
  phone_jeff => { label => "Jeff's phone", kind => 'phone' },
  phone_jen  => { label => "Jen's phone",  kind => 'phone' },
  discord    => { label => 'Discord',      kind => 'chat' },
);

sub audience_dests {
  my ($aud) = @_;
  $aud = unq($aud // '');
  return qw(phone_jeff phone_jen) if $aud eq '' || $aud =~ /\ball\b/;
  my @d;
  push @d, 'phone_jeff' if $aud =~ /\bjeff\b/;
  push @d, 'phone_jen'  if $aud =~ /\bjen\b/;
  return @d ? @d : qw(phone_jeff phone_jen);
}

## Scan a block of lines for outgoing calls. Returns { dests => [...], scripts => [...], services => [...] }.
sub scan_actions {
  my (@lines) = @_;
  my (%dests, %scripts, %services);
  for my $i (0 .. $#lines) {
    next unless $lines[$i] =~ /^\s*-?\s*(?:action|service):\s*["']?([a-z_]+\.[a-z0-9_]+)["']?\s*(?:#.*)?$/;
    my $svc = $1;
    if ($svc eq 'script.notify_phones') {
      my $aud;
      for my $j ($i + 1 .. $#lines) {
        last if $lines[$j] =~ /^\s*-?\s*(?:action|service):\s*["']?[a-z_]+\.[a-z0-9_]+/;
        if ($lines[$j] =~ /^\s*audience:\s*(.+?)\s*$/) { $aud = $1; last }
      }
      $dests{$_} = 1 for audience_dests($aud);
    }
    elsif ($svc eq 'script.notify_clear') { next }
    elsif ($svc =~ /^notify\.mobile_app_.*jeff/) { $dests{phone_jeff} = 1 }
    elsif ($svc =~ /^notify\.mobile_app_.*jen/)  { $dests{phone_jen} = 1 }
    elsif ($svc eq 'notify.discord') { $dests{discord} = 1 }
    elsif ($svc =~ /^notify\.(.+)/) { $dests{"notify_$1"} = 1; $DEST{"notify_$1"} ||= { label => $svc, kind => 'chat' } }
    elsif ($svc =~ /^script\./) { $scripts{$svc} = 1 }
    else { $services{$svc} = 1 }
  }
  return { dests => [sort keys %dests], scripts => [sort keys %scripts], services => [sort keys %services] };
}

## Entity ids listed under entity_id: (inline, flow list or block list)
sub entity_ids {
  my (@lines) = @_;
  my @e;
  for (my $i = 0; $i <= $#lines; $i++) {
    next unless $lines[$i] =~ /^\s*-?\s*entity_id:\s*(.*?)\s*$/;
    my $v = $1;
    if ($v ne '' && $v !~ /^!input/) { push @e, $v =~ /([a-z_]+\.[a-z0-9_]+)/g }
    elsif ($v eq '') {
      while ($i + 1 <= $#lines && $lines[$i + 1] =~ /^\s+-\s+["']?([a-z_]+\.[a-z0-9_]+)/) { push @e, $1; $i++ }
    }
  }
  return @e;
}

sub trigger_nodes {
  my (@lines) = @_;
  ## split into list items at the shallowest "- " indent
  my ($ind) = map { /^(\s*)-\s/ ? length($1) : () } @lines;
  return () unless defined $ind;
  my (@items, $cur);
  for (@lines) {
    if (/^\s{$ind}-\s/) { push @items, $cur = []; }
    push @$cur, $_ if $cur;
  }
  my @out;
  for my $it (@items) {
    my $text = join "\n", @$it;
    my ($type) = $text =~ /(?:platform|trigger):\s*(\w+)/;
    $type //= 'template' if $text =~ /value_template/;
    $type //= 'trigger';
    my @ent = entity_ids(@$it);
    if (@ent) {
      push @out, { label => $_, kind => 'entity' } for @ent;
      next;
    }
    my $label;
    if ($type eq 'time') { my ($at) = $text =~ /at:\s*["']?([^\s"']+)/; $label = 'time ' . ($at // '') }
    elsif ($type eq 'sun') { my ($ev) = $text =~ /event:\s*(\w+)/; $label = 'sun ' . ($ev // '') }
    elsif ($type eq 'event') { my ($ev) = $text =~ /event_type:\s*["']?([\w.]+)/; $label = 'event ' . ($ev // '') }
    elsif ($type eq 'homeassistant') { my ($ev) = $text =~ /event:\s*(\w+)/; $label = 'HA ' . ($ev // 'event') }
    elsif ($type eq 'mqtt') { my ($t) = $text =~ /topic:\s*["']?([^\s"']+)/; $label = 'mqtt ' . ($t // '') }
    elsif ($type eq 'time_pattern') { my ($m) = $text =~ /(?:minutes|hours|seconds):\s*["']?([^\s"']+)/; $label = 'every ' . ($m // '') }
    elsif ($type eq 'webhook') { $label = 'webhook' }
    else { $label = $type }
    $label =~ s/\s+$//;
    push @out, { label => $label, kind => 'schedule' };
  }
  return @out;
}

## Split a file's lines into sections keyed by the 2-space-indent keys of the item.
sub sections {
  my (@lines) = @_;
  my (%s, $key);
  for (@lines) {
    if (/^(?:- |  )([a-z_]+):\s*(.*)$/) { $key = $1; push @{ $s{$key} }, ($2 ne '' ? "  $key: $2" : "  $key:"); next }
    push @{ $s{$key} }, $_ if defined $key;
  }
  return %s;
}

## --- scripts ---------------------------------------------------------------
my %scripts;
for my $f (sort glob 'scripts/*.yaml') {
  my @lines = split /\n/, slurp($f);
  my ($name, @body, @cmt, $desc);
  my $flush = sub {
    return unless defined $name;
    my $text = join "\n", @body;
    my ($alias) = $text =~ /^\s+alias:\s*(.+)$/m;
    my $act = scan_actions(@body);
    $scripts{"script.$name"} = { id => "script.$name", label => unq($alias // $name), file => $f, act => $act, comment => $desc };
  };
  for (@lines) {
    if (/^([a-z_0-9]+):\s*$/) { $flush->(); $name = $1; @body = (); $desc = join ' ', map { s/^#+\s*//r } @cmt; @cmt = (); next }
    if (/^#/) { push @cmt, $_ if !defined $name || !@body; next }
    if (/^\S/ && !/^#/) { }
    push @body, $_ if defined $name;
    @cmt = () if /^\s*$/;
  }
  $flush->();
}

## --- blueprints --------------------------------------------------------------
my %bp = (
  'custom/sensor_alert_timeout.yaml'   => sub { my %in = @_; my @d; push @d, 'phone_jeff' if ($in{notify_jeff} // 'true') eq 'true'; push @d, 'phone_jen' if ($in{notify_jen} // 'true') eq 'true'; @d },
  'custom/sensor_alert_when_away.yaml' => sub { my %in = @_; audience_dests($in{audience} // 'jeff') },
);

## --- automations -------------------------------------------------------------
my @autos;
for my $f (sort glob 'automation/*.yaml') {
  my @lines = split /\n/, slurp($f);
  my (@items, $cur, @cmt, @pending);
  for (@lines) {
    if (/^- /) { push @items, $cur = { lines => [$_], comment => [@pending] }; @pending = (); next }
    if (/^\s*$/) { @pending = (); next }
    if (/^#/) { push @pending, $_; $cur = undef; next }
    push @{ $cur->{lines} }, $_ if $cur;
  }
  for my $it (@items) {
    my %s = sections(@{ $it->{lines} });
    my $id    = unq(join '', map { /^\s*id:\s*(.*)$/ ? $1 : () } @{ $s{id} // [] });
    my $alias = unq(join '', map { /^\s*alias:\s*(.*)$/ ? $1 : () } @{ $s{alias} // [] });
    my $desc  = unq(join '', map { /^\s*description:\s*(.*)$/ ? $1 : () } @{ $s{description} // [] });
    $desc = join ' ', map { s/^#+\s*//r } grep { !/^#+\s*$/ && !/^#{5,}/ } @{ $it->{comment} } unless $desc;
    my $a = { id => $id || $alias, alias => $alias || $id, file => $f, desc => $desc, triggers => [], dests => [], scripts => [], services => [] };
    if ($s{use_blueprint}) {
      my @b = @{ $s{use_blueprint} };
      my ($path) = map { /path:\s*(\S+)/ ? $1 : () } @b;
      my %in = map { /^\s{6}([a-z_]+):\s*(.*)$/ ? ($1, unq($2)) : () } @b;
      push @{ $a->{triggers} }, { label => $in{sensor_entity}, kind => 'entity' } if $in{sensor_entity};
      $a->{blueprint} = $path;
      push @{ $a->{dests} }, $bp{$path}->(%in) if $bp{$path};
    } else {
      my @tl = @{ $s{trigger} // $s{triggers} // [] };
      shift @tl if @tl && $tl[0] =~ /^\s+triggers?:\s*$/;
      push @{ $a->{triggers} }, trigger_nodes(@tl);
      my @al = @{ $s{action} // $s{actions} // [] };
      my $r = scan_actions(@al);
      push @{ $a->{dests} }, @{ $r->{dests} };
      push @{ $a->{scripts} }, @{ $r->{scripts} };
      push @{ $a->{services} }, @{ $r->{services} };
    }
    my %seen;
    $a->{dests} = [grep { !$seen{$_}++ } @{ $a->{dests} }];
    push @autos, $a;
  }
}

## --- assemble graph ----------------------------------------------------------
my (%nodes, @edges);
my $node = sub { my ($id, $col, $label, $kind, $extra) = @_; $nodes{$id} ||= { id => $id, col => $col, label => $label, kind => $kind, %{ $extra // {} } }; };
my $edge = sub { push @edges, { from => $_[0], to => $_[1], notify => $_[2] ? 1 : 0 } };

for my $a (@autos) {
  my $aid = "a:$a->{id}";
  $node->($aid, 1, $a->{alias}, 'automation', { file => $a->{file}, desc => $a->{desc}, blueprint => $a->{blueprint} });
  my %seen;
  for my $t (@{ $a->{triggers} }) {
    my $tid = "t:$t->{label}";
    $node->($tid, 0, $t->{label}, $t->{kind});
    $edge->($tid, $aid, 0) unless $seen{$tid}++;
  }
  for my $d (@{ $a->{dests} }) { $node->("d:$d", 3, $DEST{$d}{label}, $DEST{$d}{kind}); $edge->($aid, "d:$d", 1) }
  for my $s (@{ $a->{scripts} }) {
    next if $s =~ /^script\.notify_(phones|clear)$/;
    my $sc = $scripts{$s};
    $node->("s:$s", 2, $sc ? $sc->{label} : $s, 'script', { file => $sc ? $sc->{file} : '', desc => $sc ? $sc->{comment} : '', id => "s:$s" });
    $edge->($aid, "s:$s", 0);
  }
  for my $svc (@{ $a->{services} }) { $node->("x:$svc", 3, $svc, 'service'); $edge->($aid, "x:$svc", 0) }
}
for my $sid (sort keys %scripts) {
  next unless $nodes{"s:$sid"};
  my $sc = $scripts{$sid};
  for my $d (@{ $sc->{act}{dests} }) { $node->("d:$d", 3, $DEST{$d}{label}, $DEST{$d}{kind}); $edge->("s:$sid", "d:$d", 1) }
  for my $svc (@{ $sc->{act}{services} }) { $node->("x:$svc", 3, $svc, 'service'); $edge->("s:$sid", "x:$svc", 0) }
}

my $data = { generated => scalar localtime, nodes => [values %nodes], edges => \@edges };
my $json = JSON::PP->new->canonical->encode($data);
$json =~ s{</}{<\\/}g;

my $tmpl = slurp("$Bin/automation_map.tmpl.html");
$tmpl =~ s/\/\*DATA\*\/null/$json/;
mkdir 'docs';
open my $out, '>', 'docs/automation_map.html' or die $!;
print $out $tmpl;
close $out;
printf "wrote docs/automation_map.html: %d automations, %d nodes, %d edges\n", scalar @autos, scalar keys %nodes, scalar @edges;
