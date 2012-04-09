use Mojo::Base '-strict';
use Mojolicious::Lite;

use Test::More tests => 17;
use Test::Mojo;

use TestHelper;

plugin 'FormFields';

get '/fields' => sub { 
    shift->render(user => user());    
};

my $t = Test::Mojo->new;
$t->get_ok('/fields')->status_is(200);
$t->element_exists('input[type="file"][name="user.name"][id="fff"]');
$t->element_exists('input[type="checkbox"][name="user.admin"]');
$t->element_exists('input[type="hidden"][name="user.admin"][value="1"]');
$t->element_exists('label');
$t->text_is('label','Name'); 
$t->element_exists('input[type="password"][name="user.name"][size="10"]'); 
$t->element_exists('input[type="radio"][value="yungsta"]'); 
$t->element_exists('select[name="user.age"]');
$t->element_exists('option[value="10"]');
$t->element_exists('option[value="20"]');
$t->element_exists('option[value="30"]');
# Mojolicious' text_field has no type attr
$t->element_exists('input[name="user.name"][value="sshaw"][size="10"]');
$t->element_exists('textarea[name="user.bio"][rows="20"]');
$t->element_exists('input[type="hidden"][name="user.orders.0.id"][value="1"]');
$t->element_exists('input[type="hidden"][name="user.orders.1.id"][value="2"]');

__DATA__
@@ fields.html.ep
% my $f = fields('user');
%= $f->checkbox('admin')
%= $f->file('name', id => 'fff')
%= $f->hidden('admin')
%= $f->label('name')
%= $f->password('name', size => 10)
%= $f->radio('age', 'yungsta')
%= $f->select('age', [10,20,30])
%= $f->text('name', size => 10)
%= $f->textarea('bio', rows => '20')
% for($f->fields('orders')) {
    %= $_->hidden('id')
% }



