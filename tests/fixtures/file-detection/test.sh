#!/bin/sh
echo "what a nice bash script!!"
perl_test=$(mktemp)
cat > "${perl_test}" << "EOF2"
#!/usr/bin/perl
use YAML::XS qw(LoadFile);

sub ent {
  my ($v,$c,$p) = @_;
  ref $v eq 'HASH'
    and map { $c = ent($_,$c//0,$v) } keys %$v
    or $p and $c = ent($p->{$v},$c)
    or $v and not ref $v and $v eq "enabled" and $c++;
  return $c;
}

exit ent(LoadFile($ARGV[0]))
EOF2

echo ${fofofof}
