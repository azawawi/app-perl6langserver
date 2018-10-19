
use v6;

unit class App::Perl6LangServer;

use File::Temp;
use JSON::Fast;

#TODO refactor bin/perl6-langserver into here.

my %text-documents;

method run {

  # No standard input/output buffering to prevent unwanted hangs/failures/waits
  $*OUT.out-buffer = False;
  $*ERR.out-buffer = False;

  debug-log("🙂: Starting perl6-langserver... Reading/writing stdin/stdout.");

  my $initialized = False;
  loop {
    my %headers;
    for $*IN.lines -> $line {
      # we're done here
      last if $line eq '';

      # Parse HTTP-style header
      my ($name, $value) = $line.split(': ');
      if $name eq 'Content-Length' {
          $value = +$value;
      }
      %headers{$name} = $value;
    }

    # Read JSON::RPC request
    my $content-length = 0 + %headers<Content-Length>;
    if $content-length > 0 {
        my $json    = $*IN.read($content-length).decode;
        my $request = from-json($json);
        my $id      = $request<id>;
        my $method  = $request<method>;

        #TODO throw an exception if a method is called before $initialized = True
        given $method {
          when 'initialize' {
            my $result = initialize($request<params>);
            send-json-response($id, $result);
          }
          when 'initialized' {
            # Initialization done
            $initialized = True;
          }
          when 'textDocument/didOpen' {
            text-document-did-open($request<params>);
          }
          when 'textDocument/didSave' {
            text-document-did-save($request<params>);
          }
          when 'textDocument/didChange' {
            text-document-did-change($request<params>);
          }
          when 'textDocument/didClose' {
            text-document-did-close($request<params>);
          }
          when 'textDocument/documentSymbol' {
            # When outline tree view is shown, it asks for symbols
            my $result = on-document-symbol($request<params>);
            debug-log($result.perl);
            send-json-response($id, $result);
          }
          when 'shutdown' {
            # Client requested to shutdown...
            send-json-response($id, Any);
          }
          when 'exit' {
            exit 0;
          }
        }
    }

  }
}

sub debug-log($text) {
  $*ERR.say($text);
}

sub send-json-response($id, $result) {
  my %response = %(
    jsonrpc => "2.0",
    id       => $id,
    result   => $result,
  );
  my $json-response = to-json(%response, :!pretty);
  my $content-length = $json-response.chars;
  my $response = "Content-Length: $content-length\r\n\r\n$json-response";
  print($response);
}

sub send-json-request($method, %params) {
  my %request = %(
    jsonrpc  => "2.0",
    'method' => $method,
    params   => %params,
  );
  my $json-request = to-json(%request, :!pretty);
  my $content-length = $json-request.chars;
  my $request = "Content-Length: $content-length\r\n\r\n$json-request";
  print($request);
}

sub initialize(%params) {
  %(
    capabilities => {
      # TextDocumentSyncKind.Full
      # Documents are synced by always sending the full content of the document.
      textDocumentSync => 1,

      # Provide outline view support
      documentSymbolProvider => True
    }
  )
}

sub text-document-did-open(%params) {
  my %text-document = %params<textDocument>;
  %text-documents{%text-document<uri>} = %text-document;

  return;
}

sub publish-diagnostics($uri) {
  # Create a temporary file for Perl 6 source code buffer
	my ($file-name,$file-handle) = tempfile(:!unlink);

  # Remove temporary file when leaving lexical scope
  LEAVE unlink $file-handle;

  # Write source code and flush
  my $source = %text-documents{$uri}<text>;
	$file-handle.print($source);
  $file-handle.flush;

  # Invoke perl -c temp-filder
  #TODO handle windows platform
  my Str $output = qqx{$*EXECUTABLE -c $file-name 2>&1};

  my @problems;
  if $output !~~ /^'Syntax OK'/ &&
    $output   ~~ m/\n(.+?)at\s.+?\:(\d+)/ {

    # A syntax error occurred
    my $message     = ~$/[0];
    my $line-number = +$/[1];
    @problems.push: {
      range => {
        start => {
          line      => $line-number,
          character => 0
        },
        end => {
          line      => $line-number,
          character => 0
        },
      },
      severity => 1,
      source   => 'perl6 -c',
      message  => $message
    }
  }

  my %parameters = %(
    uri         => $uri,
    diagnostics => @problems
  );
  send-json-request('textDocument/publishDiagnostics', %parameters);
}


sub text-document-did-save(%params) {
  my %text-document = %params<textDocument>;

  return;
}

sub text-document-did-change(%params) {
  my %text-document          = %params<textDocument>;
  my $uri                    = %text-document<uri>;
  %text-documents{$uri}<text> = %params<contentChanges>[0]<text>;
  publish-diagnostics($uri);

  return;
}

sub text-document-did-close(%params) {
  my %text-document = %params<textDocument>;
  %text-documents{%text-document<uri>}:delete;

  return;
}

constant symbol-kind-file = 1;
constant symbol-kind-module = 2;
constant symbol-kind-namespace = 3;
constant symbol-kind-package = 4;
constant symbol-kind-class = 5;
constant symbol-kind-method = 6;
constant symbol-kind-property = 7;
constant symbol-kind-field = 8;
constant symbol-kind-constructor = 9;
constant symbol-kind-enum = 10;
constant symbol-kind-interface = 11;
constant symbol-kind-function = 12;
constant symbol-kind-variable = 13;
constant symbol-kind-constant = 14;
constant symbol-kind-string = 15;
constant symbol-kind-number = 16;
constant symbol-kind-boolean = 17;
constant symbol-kind-array = 18;
constant symbol-kind-object = 19;
constant symbol-kind-key = 20;
constant symbol-kind-null = 21;
constant symbol-kind-enummember = 22;
constant symbol-kind-struct = 23;
constant symbol-kind-event = 24;
constant symbol-kind-operator = 25;
constant symbol-kind-typeparameter = 26;

sub on-document-symbol(%params) {
  my %text-document = %params<textDocument>;
  my $uri = %text-document<uri>;

  # result: DocumentSymbol[] | SymbolInformation[] | null defined as follows:
  [
      {
        name => "SomeClass",
	      kind => symbol-kind-class,
	      location => {
          uri => $uri,
          range => {
            start => {
              line      => 1,
              character => 0
            },
            end => {
              line      => 1,
              character => 0
            },
          },
        },
	       #containerName? => string;
      },
      {
        name => "some-method",
	      kind => symbol-kind-method,
	      location => {
          uri => $uri,
          range => {
            start => {
              line      => 1,
              character => 0
            },
            end => {
              line      => 1,
              character => 0
            },
          },
        },
	       containerName => "SomeClass";
      },
      {
        name => "a-sub-routine",
	      kind => symbol-kind-function,
	      location => {
          uri => $uri,
          range => {
            start => {
              line      => 1,
              character => 0
            },
            end => {
              line      => 1,
              character => 0
            },
          },
        },
	       #containerName? => string;
      },
  ]
}
