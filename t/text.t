use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 8;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/text' => sub { render_input(shift, 'text') };
get '/text_with_options' => sub { render_input(shift, 'text', input => [size => 10, id => 'luser-mayne']) };

my $t = Test::Mojo->new;
$t->get_ok('/text')->status_is(200);

is_field_count($t, 'input', 1);
# Mojolicious' text_field doesn't render a type
is_field_attrs($t, 'input', { id => 'user-name', name  => 'user.name', value => 'sshaw' });

$t->get_ok('/text_with_options')->status_is(200);

is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { id => 'luser-mayne', name  => 'user.name', value => 'sshaw', size => 10 });
