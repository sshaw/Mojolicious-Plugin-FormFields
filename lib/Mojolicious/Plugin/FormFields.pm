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
    '@{}' => 'to_array',
    '""'  => 'to_string',
    fallback => 1;

our $SEPARATOR = '.';

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

sub separator { $SEPARATOR; }
sub to_string { shift->{value}; }

# ???
# field('x.y')->checkbox('value', %options)
sub checkbox
{
    my $self = shift;
    my $value = @_ % 2 ? shift : 1;
    my %options = @_;
    $options{id} //= _default_id("$self->{name}$value");

    $self->_checked_field(\%options);
    $self->{c}->check_box($self->{name}, $value, %options)
}

sub file
{
    my ($self, %options) = @_;
    $options{id} //= _default_id($self->{name});
    #$self->input('file', %options)
    $self->{c}->file_field($self->{name}, %options);
}

# ????
# field('x.y')->radio(on => "1", off => "0", %options)
# field('x.y')->radio([1,0], %options)
sub radio
{
    my ($self, %options) = @_;
    $self->_checked_field(\%options);
    $self->{c}->radio_button($self->{name}, $self->{value}, %options);
}

sub hidden
{
    my ($self, %options) = @_;
    $options{id} //= _default_id($self->{name});
    #$self->input('hidden', %options)
    $self->{c}->hidden_field($self->{name}, $self->{value}, %options);
}

sub select
{
    my $self = shift;
    my $options = @_ % 2 ? shift : [];
    my %attr = @_;
    $attr{id} //= _default_id($self->{name});

    my $c = $self->{c};
    my $name = $self->{name};
    my $field;

    if(defined $c->param($name)) {
	$field = $c->select_field($name, $options, %attr);
    }
    else {
	$c->param($name, $self->{value});
	$field = $c->select_field($name, $options, %attr);
	$c->param($name, undef); # or '' ?a
    }

    $field;
}

sub password
{
    my ($self, %options) = @_;
    $options{id} //= _default_id($self->{name});
    $self->{c}->password_field($self->{name}, %options);
}

sub label
{
    my $self = shift;

    my $text;
    $text = pop if ref $_[-1] eq 'CODE';
    $text = shift if @_ % 2;	# step on CODE
    $text ||= _default_label($self->{name});

    my %options = @_;
    $options{for} ||= _default_id($self->{name});

    $self->{c}->tag('label', %options, $text)
}

sub text
{
    my ($self, %options) = @_;
    $options{id} //= _default_id($self->{name});
    $self->{c}->text_field($self->{name}, $self->{value}, %options);
}

sub textarea
{
    my ($self, %options) = @_;
    $options{id} //= _default_id($self->{name});

    my $size = delete $options{size};
    if($size && $size =~ /^(\d+)[xX](\d+)$/) {
	$options{rows} = $1;
	$options{cols} = $2;
    }

    $self->{c}->text_area($self->{name}, %options, sub { $self->{value} });
}

sub to_array
{
    my $self = shift;
    my $value = $self->{value};
    my @children = ref($value) eq 'ARRAY' ? @$value : ($value);

    my $fields = [];

    for(my $i = 0; $i < @children; $i++) {
	my $path = "$self->{name}${SEPARATOR}$i";	
	push @$fields, $self->{c}->fields($path, $value);
	#Mojolicious::Plugin::FormFields::Fields->new($path, $children[$i], $self->{c});
    }

    $fields;
}

sub each
{
    my $self = shift;
    my $block = pop;
    my $fields = $self->to_array;

    return $fields unless ref($block) eq 'CODE';
    
    local $_;
    $block->() for @$fields;

    return;
}

sub _default_id
{
    my $name = shift;
    $name =~ s/[^\w]+/-/g;
    $name;
}

sub _default_label
{
    my $label = (split /\Q$SEPARATOR/, shift)[-1];
    $label =~ s/[^-\w]+/ /g;
    ucfirst $label;
}

sub _checked_field
{
    my ($self, $options) = @_;
    my $name = $self->{name};
    my $param = $self->{c}->param($name);

    $options->{checked} = 'checked'
	if !exists $options->{checked} && defined $param && $self->{value} eq $param;
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

  %= field('user.kinfolk')->each begin
    %= $_->hidden('id')
    %= $_->text('name')
  % end
   
  # Scoped
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
    # field('user.addressees.N.id')->hidden
    %= $_->hidden('id')

    # field('user.addressees.N.street')->text
    %= $_->text('street')

    # field('user.addressees.N.city')->select([qw|OAK PHL LAX|])
    $_->select('city', [qw|OAK PHL LAX|])
  % end

=head1 SUPPORTED FIELDS

=head2 checkbox

  # in limbo

=head2 file

  field('user.avatar')->file;

=head2 hidden

  field('user.id')->hidden

=head2 label

  field('user.name')->label
  <label for="user-name">Name</label>

  field('user.name')->label('Nombre', id => "tu_nombre_hyna")
  <label for="tu_nombre_hyna">Nombre</label>

  field('user.name')->label(id => 'x', class => 'y', sub {

  })

=head2 password

  field('user.password')->password

=head2 select

  field('user.age')->select([10,20,30])
  field('user.age')->select([10,20,30], 'data-xxx' => 'user-age-select')
  field('user.age')->select({ US => 'USA', MX => 'Mexico', BR => 'Brazil' })

=head2 radio

  # in limbo...

=head2 text

  field('user.name')->text
  field('user.name')->text(size => 10, maxlength => 32)

=head2 textarea

  field('user.bio')->textarea
  field('user.bio')->textarea(size => '5x30')

=head1 SEE ALSO

L<Mojolicious::Plugin::TagHelpers>, L<Mojolicious::Plugin::ParamExpand>
