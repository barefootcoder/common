use 5.14.0;
use warnings;
use autodie ':all';


package myperl::Classlet::keywords
{
	use Exporter;
	our @EXPORT = qw< rw with via >;

	use Scalar::Util 'blessed';
	use Symbol 'qualify_to_ref';

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

	sub _pre_has
	{
		my $attr_name = shift;
		my @props;
		for (my $i = 0; $i < @_; ++$i)
		{
			my $prop = $_[$i];
			if (blessed $prop and $prop->isa('Type::Tiny'))
			{
				push @props, isa => $prop;
			}
			else
			{
				push @props, $prop, $_[++$i];
			}
		}
		# put these at the beginning, so that if the user contradicts us, they win
		# and, since we're unshifting rather than pushing, we have to do them in reverse order of
		# how we want them to show up (not that it matters much for anything other than aesthetics)
		my %props = @props;
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
