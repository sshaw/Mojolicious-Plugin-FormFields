use Mojo::Base -strict;
use Mojolicious::Lite;

use Test::More tests => 27;
use Test::Mojo;

plugin 'FormFields';

post '/single_field' => sub {
    my $c = shift;
    my $f = $c->field('name');
    $f->is_required;

    my $json = { valid => $f->valid, error => $f->error };
    $c->render(json => $json);
};

post '/multiple_fields' => sub {
    my $c = shift;
    $c->field('name')->is_required;
    $c->field('password')->is_required;

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};

post '/scoped_field' => sub {
    my $c = shift;
    my $user = $c->fields('user');
    $user->is_required('name');

    my $json = { valid => $user->valid, errors => $user->errors('name') };
    $c->render(json => $json);
};

post '/custom_validation_rule' => sub {
    my $c = shift;
    $c->field('name')->check(sub {
        $_[0] =~ /^sshaw$/ ?  undef : 'what what what';
    });

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};

post '/validation_rules_can_be_chained' => sub {
    my $c = shift;
    $c->field('name')->is_required->is_like(qr/\d/);
    $c->field('password')->is_like(qr/\d/)->is_required;

    my $json = { valid => $c->valid, errors => $c->errors };
    $c->render(json => $json);
};

my $t = Test::Mojo->new;
$t->post_ok('/single_field')->status_is(200)->json_is({valid => 0, error => 'Required'});
$t->post_ok('/single_field', form => { name => 'sshaw' })->status_is(200)->json_is({valid => 1, error => undef});

$t->post_ok('/multiple_fields')->status_is(200)->json_is({valid => 0,
                                                          errors => { 'name' => 'Required',
                                                                      'password' => 'Required' }});
$t->post_ok('/multiple_fields', form => { name => 'sshaw', password => '@s5' })->status_is(200)->json_is({valid => 1, errors => {}});

$t->post_ok('/scoped_field', form => { 'user.name' => 'sshaw' })->status_is(200)->json_has({valid => 1, errors => {}});

$t->post_ok('/custom_validation_rule',
            form => { 'name' => 'fofinha' })->status_is(200)->json_is({valid => 0, errors => { 'name' => 'what what what' }});
$t->post_ok('/custom_validation_rule',
            form => { 'name' => 'sshaw' })->status_is(200)->json_is({valid => 1, errors => {}});

$t->post_ok('/validation_rules_can_be_chained',
            form => { 'name' => 'ABC', 'password' => 'XYZ' })->status_is(200)->json_is({valid => 0,
                                                                                        errors => { 'name' => 'Invalid value',
                                                                                                    'password' => 'Invalid value' }});
$t->post_ok('/validation_rules_can_be_chained',
            form => { 'name' => '4sho', 'password' => 'x11' })->status_is(200)->json_is({valid => 1, errors => {}});
