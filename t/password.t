use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 8;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/password' => sub { render_input(shift, 'password') };
get '/password_with_options' => sub { render_input(shift, 'password', input => [size => 10, maxlength => 20, id => 'pASS']) };

my $t = Test::Mojo->new;
$t->get_ok('/password')->status_is(200);

is_field_count($t, 'input', 1);
# Mojolicious' password_field does not render a value attr
is_field_attrs($t, 'input', { id => 'user-name', name => 'user.name', type => 'password' }); 

$t->get_ok('/password_with_options')->status_is(200);

is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { id => 'pASS', name => 'user.name', type => 'password', size => 10, maxlength => 20 }); 
