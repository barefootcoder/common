package perl5::barefoot;
use parent 'perl5';


sub imports
{
	return
	(
		strict				=>
		warnings			=>
		feature				=>	[ ':5.12'],

		TryCatch						=>
		'Const::Fast'					=>
		'Path::Class'					=>
		'Perl6::Slurp'					=>
		'MooseX::Declare'				=>
		'Method::Signatures'			=>	20111125,
		'Method::Signatures::Modifiers'	=>
	);
}


1;
