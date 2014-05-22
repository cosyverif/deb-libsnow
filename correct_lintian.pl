#! /usr/bin/perl -sW

# We are going to read the build file (a log of the source package building)
# in slurp mode, then we will check each possible error (not exhaustively)
# detected by lintian (a tool that checks if the package is conform with
# Debian policy) and correct the package building configuration files 
# accordingly.

use strict;

if(our$h) {
    print "correct_lintian [-l] [-s] source_build_log\n\nDescritpion:\n\tCorrects the debian folder built by dh_make using the .build file\n\tgenerated by 'debuild -S' command.\n\nOptions:\n";
    print "\t-l:\t enable if you are building a library.\n";
    print "\t-s:\t enable if you are building binaries in a single package.\n";
    exit 0;
}

print "Starting configuration files edition due to lintian messages.\n";

my$buildfilename = shift;
open BUILDLOG, $buildfilename;
$/ = undef;
my$log = <BUILDLOG>;    # the entire building log

$log =~ m/Now running lintian\.\.\.\n(.*)\nFinished running lintian/s;
my$lintianLog = $1;  # the lintian part of the log

# Opening configuration files
open CONTROL, "debian/control" or die($!);
my$control = <CONTROL>;
close CONTROL;

# Opening log file
open LOG, ">", "../$ENV{LOGFILE}" or die($!);

# Matching errors and correcting
if ( $lintianLog =~ /package-needs-versioned-debhelper-build-depends (.*?)[\s]/ ) {
    my$dh_version = $1;
    $control =~ s/debhelper (\(.*?\))/debhelper \(>= $dh_version\)/;
    print LOG "build depends debhelper version changed from $1 to (>= $dh_version)\n";
}
if ( $lintianLog =~ /out-of-date-standards-version \d\.\d\.\d \(current is (\d\.\d\.\d)\)/ ) {
    my$std_version = $1;
    $control =~ s/Standards-Version: (\d\.\d\.\d)/Standards-Version: $std_version/;
    print LOG "standards version changed from $1 to $std_version\n";
}
if ( $lintianLog =~ /ancient-standards-version \d\.\d\.\d \(current is (\d\.\d\.\d)\)/ ) {
    my$std_version = $1;
    $control =~ s/Standards-Version: \d\.\d\.\d/Standards-Version: $std_version/;
    print LOG "standards version changed from $1 to $std_version\n";
}
if ( $lintianLog =~ /debhelper-but-no-misc-depends/ ) {
    $control =~ s/(Package: (.*-dev)[\s]+Section:.*?[\s]+Architecture:.*?[\s]+Depends:.*?)([\s]*Desc)/$1, \${misc:Depends}$3/s;
    print LOG "added missing dependencies for $2 package\n";
}
if ( $lintianLog =~ /bad-homepage/ ) {
    $control =~ s/(Homepage: )<.*?>/$1$ENV{HOMEPAGE}/;
    print LOG "added homepage\n";
}
if ( $lintianLog =~ /binary-without-manpage/ ) {
    print LOG "WARNING: Each binary in /usr/bin, /usr/sbin, /bin, /sbin or /usr/games should have a manual page.\n
\tIf the man pages are provided by another package on which this package depends, lintian may not be able to determine\n
\tthat man pages are available. In this case, ignore this warning\n";
}


# Writing in files
open CONTROL, ">", "debian/control" or die($!);
print CONTROL $control;

# Closing files
close CONTROL;
close BUILDLOG;
close LOG;


print "Configuration files edited ! You can find what has been changed in $ENV{LOGFILE}\n";
