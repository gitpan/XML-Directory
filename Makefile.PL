use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

$VERSION = '0.60';

WriteMakefile(
    'NAME'		=> 'XML::Directory',
    'VERSION_FROM'	=> 'Directory.pm',
    'PREREQ_PM'		=> {},#{mod_perl => 1.0}
    dist	        => {COMPRESS => 'gzip', SUFFIX => 'tar.gz'},
);
