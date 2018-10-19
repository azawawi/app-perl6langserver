use v6;

my $source-code = q:to/END/;
  unit class Foo;

  method A { }
  sub B { }
  sub foo {
    my $var = 1;
    say "Hello, World!";
  }
  END

"foofoo.p6".IO.spurt: $source-code;
LEAVE "foofoo.p6".IO.unlink;

my $output = qq:x{perl6 --target=parse foofoo.p6};
"ast-tree.txt".IO.spurt: $output;

my @array;
my (Int $indent, $rule, $value);
for $output.lines -> $line {
  if $line ~~ /^ (\s+) '- ' (\w+) ': ' (.+?) $/ {
    
    if $rule.defined {
      # say "$indent: $rule => $value";
      @array.push( {
          indent => $indent,
          rule   => $rule,
          value  => $value,
      });
    }

    $indent = Int(~$/[0].chars / 2);
    $rule   = ~$/[1];
    $value  = ~$/[2];
  } else {
    $value ~= $line;
  }

  # if $line ~~ /'package_declarator'/
  
  # if $line ~~ /'routine_declarator'/ {
  #   say $line;
  # }
  # if $line ~~ /'method_declarator'/ {
  #   say $line;
  # }
  # if $line ~~ /'identifier:' \s+ (.+?)$/ {
  #   say "Identifier => " ~ ~$/[0]
  # } elsif $line ~~ /'quote:' \s+ (.+?)$/ {
  #   say "Quote      => " ~ ~$/[0]
  # } elsif $line ~~ /'variable:' \s+ (.+)$/ {
  #   say "Variable   => " ~ ~$/[0]
  # } elsif $line ~~ /'integer:' \s+ (.+)$/ {
  #   say "Integer    => " ~ ~$/[0]
  # }
}

for @array -> $item {
  if $item<rule> eq 'package_declarator' {
    
  }
}
