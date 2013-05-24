package myperl::Template;

use myperl;

use Template;


our $TT = Template->new({
	#INCLUDE_PATH	=>	'.',
});


method import ($class: @dirs)
{
	debuggit(6 => "args to myperl::Template::import are:", DUMP => \@_);

	if (@dirs)
	{
		my $provider = $TT->context->{'LOAD_TEMPLATES'}->[0];
		my $includes = $provider->include_path;
		push @$includes, @dirs;
		debuggit(4 => "template includes are:", DUMP => $includes);
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
