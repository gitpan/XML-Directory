use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::Directory',
    'VERSION_FROM'	=> 'Directory.pm',
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
);
