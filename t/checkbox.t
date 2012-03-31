use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 4;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/checkbox' => sub { render_input(shift, 'checkbox') }; 

my $t = Test::Mojo->new;
$t->get_ok('/checkbox')->status_is(200);

is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { type => 'checkbox', name  => 'user.name', value => '1' });
