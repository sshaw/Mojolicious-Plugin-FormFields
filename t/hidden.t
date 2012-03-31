use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More 'no_plan'; 
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/hidden' => sub { render_input(shift, 'hidden') };

my $t = Test::Mojo->new;
$t->get_ok('/hidden')->status_is(200);

is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { id => 'user-name', name => 'user.name', type => 'hidden', value => 'sshaw' }); 
