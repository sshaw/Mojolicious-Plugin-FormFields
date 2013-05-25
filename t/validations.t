use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 18;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';
post '/invalid_single_field' => sub {
    my $c = shift;
    my $f = $c->field('user.name');
    $f->is_required;

    my $json = { valid => $f->valid, error => $f->error };
    $c->render(json => $json);
};

post '/invalid_multiple_fields' => sub {
    my $c = shift;
    $c->field('user.name')->is_required;
    $c->field('user.password')->is_required;

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};

post '/validation_rule_with_a_custom_sub' => sub {
    my $c = shift;
    $c->field('user.name')->check(sub {
	$_[0] =~ /^sshaw$/ ?  undef : 'what what what';
    });

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};

post '/validation_rules_can_be_chained' => sub {
    my $c = shift;
    $c->field('user.name')->is_required->is_like(qr/\d/);
    $c->field('user.password')->is_like(qr/\d/)->is_required;

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};


my $t = Test::Mojo->new;
$t->post_ok('/invalid_single_field')->status_is(200)->json_is({valid => 0, error => 'Required'});
$t->post_ok('/invalid_multiple_fields')->status_is(200)->json_is({valid => 0,
								  errors => { 'user.name' => 'Required',
									      'user.password' => 'Required' }});

$t->post_ok('/validation_rule_with_a_custom_sub',
	    form => { 'user.name' => 'fofinha' })->status_is(200)->json_is({valid => 0, errors => { 'user.name' => 'what what what' }});

$t->post_ok('/validation_rule_with_a_custom_sub',
	    form => { 'user.name' => 'sshaw' })->status_is(200)->json_is({valid => 1, errors => {}});

$t->post_ok('/validation_rules_can_be_chained',
	    form => { 'user.name' => 'ABC', 'user.password' => 'XYZ' })->status_is(200)->json_is({valid => 0,
												  errors => { 'user.name' => 'Invalid value',
													      'user.password' => 'Invalid value' }});
$t->post_ok('/validation_rules_can_be_chained',
	    form => { 'user.name' => '4sho', 'user.password' => 'x11' })->status_is(200)->json_is({valid => 1, errors => {}});
