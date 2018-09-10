use 5.14.0;
use warnings;
use autodie ':all';


package myperl::Classlet::keywords
{
	use Exporter;
	our @EXPORT = qw< rw with via per Array Hash >;

	use List::Util 'any';
	use Scalar::Util 'blessed';
	use Symbol 'qualify_to_ref';
	use Types::Standard qw< ArrayRef HashRef >;

	sub _wrap_caller_func
	{
		my ($method, $pre_coderef) = @_;
		my $caller = caller(1);

		# this code is essentially a stripped-down version of Sub::Prepend
		# 	(Copyright 2007-2008 Johan Lodin; licensed under the same terms as Perl itself)
		# but modified to accomodate our slightly weirder needs
		my $caller_glob = qualify_to_ref($method => $caller);
		if (exists &$caller_glob)					# probably `has`
		{
			no warnings 'redefine';
			my $caller_ref  = \&$caller_glob;
			  *$caller_glob = sub { &$pre_coderef; goto &$caller_ref };
		}
		else										# something else, but still wrap the caller's `has`
		{
			my $caller_ref  = \&{ qualify_to_ref(has => $caller) };
			  *$caller_glob = sub { &$pre_coderef; goto &$caller_ref };
		}
	}

	sub import
	{
		# wrap our caller's `has` with our own version
		_wrap_caller_func(has => \&myperl::Classlet::keywords::_pre_has);

		# now our other `has` wrappers
		_wrap_caller_func(builds => \&myperl::Classlet::keywords::_pre_builds);

		goto &Exporter::import;
	}


	# these work similar to MooseX::Has::Sugar
	sub rw () { is => 'rw' }

	# these are the official prepositions of Onyx Moose
	sub with    {                  default =>                  shift          }
	sub via (&) { my $def = shift; default => sub { local $_ = shift; &$def } }
	sub per     {                  handles => { @_ }                          }

	# these are syntax helpers for "native traits" (more properly called "native delegations")
	sub Array   { NATIVE => 'Array', }
	sub Hash    { NATIVE =>  'Hash', }

	sub _pre_has
	{
		my $attr_name = shift;
		my $native;
		my @props;
		for (my $i = 0; $i < @_; ++$i)
		{
			my ($prop, $next) = ($_[$i], $_[$i+1]);
			if (blessed $prop and $prop->isa('Type::Tiny'))
			{
				push @props, isa => $prop;
			}
			elsif ($prop eq 'NATIVE')
			{
				$native = $next;
				++$i;			# skip next; we're using it for the native trait
			}
			else
			{
				push @props, $prop, $next;
				++$i;			# skip next, 'cause we've already pushed it
			}
		}
		# put these at the beginning, so that if the user contradicts us, they win
		# and, since we're unshifting rather than pushing, we have to do them in reverse order of
		# how we want them to show up (not that it matters much for anything other than aesthetics)
		my %props = @props;
		if ($native)
		{
			my %isa     = ( Array => ArrayRef,   Hash => HashRef,    );
			my %default = ( Array => sub { [] }, Hash => sub { {} }, );
			unshift @props, default => $default{$native} unless exists $props{default} or exists $props{builder};
			unshift @props, isa     => $isa{$native}     unless exists $props{isa};
			if (exists $props{traits})
			{
				push @{$props{traits}}, $native;
			}
			else
			{
				unshift @props, traits => [$native];
			}
			# slightly tricky: if the user has not specified a method to call the native `elements`,
			# make the attr name be that method, and then rename the attr itself to be private
			my $elements_set = exists $props{handles} && any { $_ eq 'elements' } values %{$props{handles}};
			if ( not $elements_set )
			{
				# public accessor will use the base name
				$props{handles} //= {};
				$props{handles}->{$attr_name} = 'elements';
				# allow ctor override using the public name, unless there already is one
				unshift @props, init_arg => $attr_name unless exists $props{init_arg};
				# privatize the attribute name
				$attr_name = '_' . $attr_name;
			}
		}
		unshift @props, required => 1 unless exists $props{default} or exists $props{builder};
		unshift @props, is => 'ro'    unless exists $props{is};
		unshift @props, $attr_name;
		@_ = @props;
	}

	sub _pre_builds
	{
		splice @_, 1, 0, lazy => 1;
	}
}

# this keeps Moops::import from trying to load a non-existent keywords.pm file
$INC{'myperl/Classlet/keywords.pm'} = __FILE__;


package myperl::Classlet
{
	use parent 'Moops';

	sub import
	{
		my ($class, %opts) = @_;

		# as per L<Moops/"Extending Moops via imports">
		push @{ $opts{imports} //= [] },
		(
			warnings						=>	[ FATAL => 'all' ],
			'myperl::Classlet::keywords'	=>	[ @myperl::Classlet::keywords::EXPORT ],
		);

		$class->SUPER::import(%opts);
	}
}


1;
