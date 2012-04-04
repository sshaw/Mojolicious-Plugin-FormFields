package Mojolicious::Plugin::FormFields;

use Mojo::Base 'Mojolicious::Plugin::ParamExpand';

our $VERSION = '0.01';

sub register
{
  my ($self, $app, $config) = @_;

  $config->{separator} = Mojolicious::Plugin::FormFields::Field->separator;
  $self->SUPER::register($app, $config);

  $app->helper(field => sub {
      # cache by name
      Mojolicious::Plugin::FormFields::Field->new(@_);
  });

  $app->helper(fields => sub {
      Mojolicious::Plugin::FormFields::Fields->new(@_);
  });
}

package Mojolicious::Plugin::FormFields::Field;

use Mojo::Base '-strict';
use Mojo::Util;
use Scalar::Util;
use Carp ();

use overload
    '@{}' => '_to_fields',
    '""'  => '_to_string',
    fallback => 1;

my $SEPARATOR = '.';

sub new
{
    my $class = shift;
    my ($c, $name, $object) = @_;
    Carp::croak 'field name required' unless $name;

    my $self = bless {
	c     => $c,
	name  => $name,
	value => _lookup_value($name, $object, $c)
    }, $class;

    Scalar::Util::weaken $self->{c};
    $self;
}

sub checkbox
{
    my $self = shift;

    my $value; 
    $value = shift if @_ % 2;
    $value //= 1;

    my %options = @_;
    $options{id} //= _dom_id($self->{name}, $value);

    $self->_checked_field($value, \%options);
    $self->{c}->check_box($self->{name}, $value, %options)
}

sub file
{
    my ($self, %options) = @_;
    $options{id} //= _dom_id($self->{name});

    $self->{c}->file_field($self->{name}, %options);
}

sub radio
{
    my ($self, $value, %options) = @_;
    Carp::croak 'value required' unless defined $value;

    $options{id} //= _dom_id($self->{name}, $value);
    $self->_checked_field($value, \%options);    

    $self->{c}->radio_button($self->{name}, $value, %options);
}

sub hidden
{
    my ($self, %options) = @_;
    $options{id} //= _dom_id($self->{name});

    $self->{c}->hidden_field($self->{name}, $self->{value}, %options);
}

sub select
{
    my $self = shift;
    my $options = @_ % 2 ? shift : [];
    my %attr = @_;
    $attr{id} //= _dom_id($self->{name});

    my $c = $self->{c};
    my $name = $self->{name};
    my $field;

    if(defined $c->param($name)) {
	$field = $c->select_field($name, $options, %attr);
    }
    else {
	# Make select_field select the value
	$c->param($name, $self->{value});
	$field = $c->select_field($name, $options, %attr);
	$c->param($name, undef);
    }

    $field;
}

sub password
{
    my ($self, %options) = @_;
    $options{id} //= _dom_id($self->{name});

    $self->{c}->password_field($self->{name}, %options);
}

sub label
{
    my $self = shift;

    my $text;
    $text = pop if ref $_[-1] eq 'CODE';
    $text = shift if @_ % 2;	# step on CODE
    $text //= _default_label($self->{name});

    my %options = @_;
    $options{for} //= _dom_id($self->{name});

    $self->{c}->tag('label', %options, $text)
}

sub text
{
    my ($self, %options) = @_;
    $options{id} //= _dom_id($self->{name});

    $self->{c}->text_field($self->{name}, $self->{value}, %options);
}

sub textarea
{
    my ($self, %options) = @_;
    $options{id} //= _dom_id($self->{name});

    my $size = delete $options{size};
    if($size && $size =~ /^(\d+)[xX](\d+)$/) {
	$options{rows} = $1;
	$options{cols} = $2;
    }

    $self->{c}->text_area($self->{name}, %options, sub { $self->{value} });
}

sub each
{
    my $self = shift;
    my $block = pop;
    my $fields = $self->_to_fields;

    return $fields unless ref($block) eq 'CODE';
    
    local $_;
    $block->() for @$fields;

    return;
}

sub separator { $SEPARATOR; }

sub _to_string { shift->{value}; }

sub _to_fields
{
    my $self = shift;
    my $value = $self->{value};

    my $fields = [];
    return $fields unless ref($value) eq 'ARRAY';

    my $i = -1;
    while(++$i < @$value) {
	my $path = "$self->{name}${SEPARATOR}$i";	
	push @$fields, $self->{c}->fields($path, $value);
    }

    $fields;
}

sub _dom_id
{
    my @name = @_;
    s/[^\w]+/-/g for @name;
    join '-', @name;
}

sub _default_label
{
    my $label = (split /\Q$SEPARATOR/, shift)[-1];
    $label =~ s/[^-a-z0-9]+/ /ig;
    ucfirst $label;
}

sub _checked_field
{
    my ($self, $value, $options) = @_;
    $options->{checked} = 'checked'
	if !exists $options->{checked} && defined $self->{value} && $self->{value} eq $value;
}

sub _lookup_value
{
    my ($name, $object, $c) = @_;
    my @path = split /\Q$SEPARATOR/, $name;

    if(!$object) {
	$object = $c->stash($path[0]);
	_invalid_parameter($name, "nothing in the stash for '$path[0]'") unless $object;
    }

    # Remove the stash key for $object
    shift @path;

    while(defined(my $accessor = shift @path)) {
	my $isa = ref($object);

	# We don't handle the case where one of these return an array
	if(Scalar::Util::blessed($object) && $object->can($accessor)) {
	    $object = $object->$accessor;
	}
	elsif($isa eq 'HASH') {
	    # If blessed and !can() do we _really_ want to look inside?
	    $object = $object->{$accessor};
	}
	elsif($isa eq 'ARRAY') {
	    _invalid_parameter($name, "non-numeric index '$accessor' used to access an ARRAY")
		unless $accessor =~ /^\d+$/;

	    $object = $object->[$accessor];
	}
	else {
	    my $type = $isa || 'type that is not a reference';
	    _invalid_parameter($name, "cannot use '$accessor' to access a $type");
	}
    }

    $object;
}

sub _invalid_parameter
{
    my ($field, $message) = @_;
    Carp::croak "Invalid parameter '$field': $message";
}

package Mojolicious::Plugin::FormFields::Fields;

use Mojo::Base '-strict';
use Carp ();

sub new
{
    my ($class, $c, $name, $object) = @_;
    Carp::croak 'object name required' unless $name;

    my $self = bless {
	c      => $c,
	name   => $name, #path?
	object => $object
    }, $class;

    Scalar::Util::weaken $self->{c};
    $self;
}

my $sep = Mojolicious::Plugin::FormFields::Field->separator;

for my $field qw(checkbox file hidden input label password radio select text textarea) {
    no strict 'refs';
    *$field = sub {
        my $self = shift;
        my $name = shift;
        Carp::croak 'field name required' unless $name;
	
        my $path = "$self->{name}$sep$name"; 
	$self->{c}->field($path, $self->{object}, $self->{c})->$field(@_);
    };
}


1;

__END__

=pod

=head1 NAME

Mojolicious::Plugin::FormFields - Use objects and data structures in your forms

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('FormFields', %options);

  # Mojolicious::Lite
  plugin 'FormFields', %options;

  # In your action
  sub edit
  {
      my $self = shift;
      my $user = $self->find_user($self->param('id'));
      $self->stash(user => $user);
  }

  # In your view
  %= field('user.name')->text;
  %= field('user.age')->select([10,20,30]);
  %= field('user.password')->password;

  # Fields for a collection
  %= field('user.kinfolk')->each begin
    %= $_->hidden('id')
    %= $_->text('name')
  % end

  # Same as above
  % my $kinfolk = field('user.kinfolk');
  % for my $person (@$kinfolk) {
    %= $person->hidden('id')
    %= $person->text('name')
  % }
   
  # Scoped to user
  % my $f = fields('user');
  %= $f->text('name');
  %= $f->select('age', [10,20,30]);
  %= $f->password('password');

=head1 DESCRIPTION

L<Mojolicious::Plugin::FormFields> turns request parameters into nested data
structures using L<CGI::Expand> and helps you use these values in a form.

=head1 METHODS

=head2 field

Create form fields

  %= field('user.name')->text

Same as

  %= text_field 'user.name', $user->name, id => 'user-name'

If the expanded representation of the parameter exists in
L<the stash|Mojolicious::Controller/stash> it will be used as the default.
If a value for the flattened representation exists (e.g., from a form submission)
it will be used instead.

You can also supply the object or reference to retrieve the value from

  <%= field('book.upc', $item)->text %>

=head3 Arguments

C<$name>

The name of the parameter.

C<$object>

Optional. The object to retrieve the default value from. Must be a reference to a
hash, an array, or something blessed. If not given the value will be retrieved from
the stash or, for previously submitted forms, the request parameter C<$name>.

=head3 Returns

HTML form field

=head3 Errors

An error will be raised if:

=over 4

=item * C<$name> is not provided

=item * C<$name> cannot be retrieved from C<$object>.

=item * C<$object> cannot be found in the stash and no default was given

=back

=head2 fields

Create form fields scoped to a parameter. 

For example 

  % $f = fields('user')
  %= $f->select('age', [10,20,30])
  %= $f->textarea('bio')

Is the same as

  %= field('user.age')->select([10,20,30])
  %= field('user.bio')->textarea

=head2 each

Iterate over a collection scoping each element via C<<  L<fields> >>.

  %= field('user.addressees')->each begin
    %# field('user.addressees.N.id')->hidden
    %= $_->hidden('id')

    %# field('user.addressees.N.street')->text
    %= $_->text('street')

    %# field('user.addressees.N.city')->select([qw|OAK PHL LAX|])
    $_->select('city', [qw|OAK PHL LAX|])
  % end

=head1 SUPPORTED FIELDS

=head2 checkbox

  field('user.admin')->checkbox(%options)

  <input type="checkbox" name="user.admin" id="user-admin" value="1"/>

  field('user.admin')->checkbox('yes', %options)

  <input type="checkbox" name="user.admin" id="user-admin" value="yes"/>

=head2 file

  field('user.avatar')->file;

=head2 hidden

  field('user.id')->hidden

=head2 label

  field('user.name')->label
  <label for="user-name">Name</label>

  field('user.name')->label('Nombre', for => "tu_nombre_hyna")
  <label for="tu_nombre_hyna">Nombre</label>

  field('user.name')->label(for => 'x', class => 'y', sub {

  })

=head2 password

  field('user.password')->password

=head2 select

  field('user.age')->select([10,20,30])
  field('user.age')->select({10 => 'Ten', 20 => 'Dub', 30 => 'Trenta'}, %options)

=head2 radio

  field('user.age')->radio('21 & Over')

=head2 text

  field('user.name')->text
  field('user.name')->text(size => 10, maxlength => 32)

=head2 textarea

  field('user.bio')->textarea
  field('user.bio')->textarea(size => '5x30')

=head1 SEE ALSO

L<Mojolicious::Plugin::TagHelpers>, L<Mojolicious::Plugin::ParamExpand>
