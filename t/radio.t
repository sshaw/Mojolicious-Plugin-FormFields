use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 4;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/radio' => sub { render_input(shift, 'radio') }; #, input => ['yes']) };

my $t = Test::Mojo->new;
$t->get_ok('/radio')->status_is(200);

is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { type => 'radio', name  => 'user.name', value => 'sshaw' });
