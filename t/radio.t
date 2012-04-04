use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 10;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/radio' => sub { render_input(shift, 'radio', input => ['sshaw']) };
get '/radio_value_required' => sub { render_input(shift, 'radio') };

my %base_attr = (type => 'radio', name  => 'user.name', id => 'user-name-sshaw', value => 'sshaw');
my $t = Test::Mojo->new;
$t->get_ok('/radio')->status_is(200);
is_field_count($t, 'input', 1);
is_field_attrs($t, 'input', { %base_attr, checked => 'checked' });

$t->get_ok('/radio?user.name=xxx')->status_is(200);
is_field_attrs($t, 'input', \%base_attr);

$t->get_ok('/radio_value_required')
    ->status_is(500)
    ->content_like(qr/value required/);

__DATA__
@@ exception.html.ep
%= stash('exception')
