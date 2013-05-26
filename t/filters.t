use Mojo::Base -strict;
use Mojolicious::Lite;

use Test::More tests => 9;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

post '/single_filter' => sub {
    my $c = shift;
    $c->field('name')->filter('uc');
    $c->valid;			# trigger filter
    $c->render(text => $c->param('name'));
};

post '/multiple_filters' => sub {
    my $c = shift;
    $c->field('name')->filter('uc', 'strip')->filter('trim');
    $c->valid;
    $c->render(text => $c->param('name'));
};

post '/custom_filter' => sub {
    my $c = shift;
    $c->field('name')->filter(sub { chop $_[0]; $_[0] });
    $c->valid;
    $c->render(text => $c->param('name'));
};

my $t = Test::Mojo->new;
$t->post_ok('/single_filter',
	    form => { 'name' => 'fofinha' })->status_is(200)->content_is('FOFINHA');

$t->post_ok('/multiple_filters',
	    form => { 'name' => ' a   b     c   ' })->status_is(200)->content_is('A B C');

$t->post_ok('/custom_filter',
	    form => { 'name' => 'foo!' })->status_is(200)->content_is('foo');
