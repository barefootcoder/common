package myperl::Template;

use myperl;

use Template;


our $TT = Template->new({
	#INCLUDE_PATH	=>	'.',
});


method import ($class: @dirs)
{
	if (@dirs)
	{
		my $provider = $TT->context->{'LOAD_TEMPLATES'}->[0];
		my $includes = $provider->include_path;
		push @$includes, @dirs;
		$provider->include_path($includes);
	}
}


func templ::process ($template, $vars)
{
	my $output = '';
	$TT->process($template, $vars, \$output) || die($TT->error);
	return $output;
}


1;
