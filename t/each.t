use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 10;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

my $users = [ user(name => 'user_a'), user(name => 'user_b') ];

get '/to_array' => sub { 
    my $self = shift;
    my $text = join '', map $_->text('name'), @{$self->field('users', $users)};
    $self->render(text => $text);
};

get '/each' => sub { 
    my $self = shift;
    my $text = '';
    $self->field('users', $users)->each(sub { $text .= $_->text('name') });
    $self->render(text => $text);
};


sub match_elements
{
    my $t = shift;
    is_field_count($t, 'input', 2);
    $t->element_exists('input[id="users-0-name"][value="user_a"]');
    $t->element_exists('input[id="users-1-name"][value="user_b"]');
}

my $t = Test::Mojo->new;
$t->get_ok('/to_array')->status_is(200);
match_elements($t);

$t = Test::Mojo->new;
$t->get_ok('/each')->status_is(200);
match_elements($t);
