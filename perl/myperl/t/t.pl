use myperl DEBUG => 2;

class Foo
{
	warn("Foo::DEBUG should now be " . (eval "Foo::DEBUG" // 'undef'));
}
