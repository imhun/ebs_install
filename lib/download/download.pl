#
# $Header: download.pl 121.3 2011/07/06 00:00:00 Zheng.liu noship $
#
# *===========================================================================+
# |  Copyright (c) 2011 China Resources (Holdings) Co., Ltd.                  |
# |                        All rights reserved                                |
# |                       Applications  Division                              |
# +===========================================================================+
# |
# | FILENAME
# |      download.pl
# |
# | DESCRIPTION
# |      This script is used to download customer application and setups
# |
# | PLATFORM
# |      Unix Generic
# |
# | NOTES
# |
# | HISTORY
# |        2011-7-6     Zheng.Liu       creation
# +===========================================================================+
# dbdrv: none 

eval 'exec perl -S $0 "$@"'
if $running_under_some_shell;

use Config;
 
BEGIN {
    require 5.004;
}

BEGIN {
    # build perl library path environment: PERL5LIB
    #
    # verify, update the include path to be  pointing to 
    # the perl distribution in the iAS or COMMON_TOP Apache HOME.
    if ($Config{'osname'} ne "MSWin32" && (! $ENV{'PERL5LIB'})) {
        my $value = "";
        my $envkey = "";
        my @tmpINC = ();
        my $perlPath = "";
        my $pcmd = 'perl';
        foreach (split /:/, $ENV{PATH}) {
            $perlPath = "$_/$pcmd", last if -x "$_/$pcmd";
        }
        my $dir = ""; 
        if ($perlPath =~ /(.*?\/)perl/) {
            $dir = $1;
        }
 
        if ($dir =~ /Apache/) {
            my $swap_plib = 0;
 
            # this covers the build case for the 11.5.1 perl
            # distribution in Apache.
            if (-d "${dir}perl/perl5/5.00503") {
                $swap_plib = 1;
            }
            foreach $value (@INC) {
                if ($value =~ /.*?(perl.*)/) {
                    my $plib_home = $1;
 
                    if ($swap_plib) {
                        $plib_home =~ s/perl\/lib/perl\/perl5/;
                    }
                    push @tmpINC, "${dir}$plib_home";
                }
            }
            @INC = @tmpINC;
        }
    }
}
 
use strict;
use POSIX qw(strftime);
use Cwd;
use FileHandle;
use File::Path;
use TXK::FileSys;
use TXK::Runtime;
use ADX::util::Sysutil;
use ADX::util::Java;

# +===========================================================================+
# | Global Declarations
# +===========================================================================+
my %arg;			# hash store arguments
my %ctx; 			# hash store context variables of config file
my %cfg; 			# hash store others variables of config file
my $basepath; #install base path
my $appl_top; # appl top path
my $au_top; 	# au top path
my $fnd_top; 	# fnd top path
my $rac_mode; # rac mode

my $currentType; 	# current install step
my $currentLang; 	# current install language
my $currentDir; 	# current install director
my $currentFile; 	# current install file
my $baseLanguageFlag;   # base language flag

# +===========================================================================+
# | local variables
# +===========================================================================+
my @_type; # array of object types
my %_typeConfig; 	#hash store download types config
my @_objectList; # array of object List at current type
my @_lang; # array of application install language
my %_isoLang; # hash store install iso language
my %_envLang; # hash store ENV language
my @_supportProg = ("sqlplus","FndXdfCmp","frmcmp_batch","f60gen",
                   "WFLOAD","fndload","xdoload","XMLImporter","cpshell","userdefine");
my $gProgname = "download tools";
my $gProgVersion = "12.1.3";
my $gRunTimeString;
# my $perlOps;
my $javaOps;
my $util;
my $fsys;

sub main{

	$gRunTimeString = strftime "%m%d%H%M", localtime;
	#($gProgname = $0) =~ s,.*[/\\],,;
	
	autoflush STDOUT 1;
	# set operating system specific platform informations
	setOSspecifics();
	# get current dir
  $arg{'currentdir'} = Cwd::cwd();
  # get file system handle
  $fsys = TXK::FileSys->new();
  # print banner
  printBanner();
  ## Verifying environment settings $APPL_TOP, $NLS_LANG, $FND_TOP, $AU_TOP, $CONTEXT_FILE
	if ( ("$ENV{APPL_TOP}x" eq "x") ||
	     ("$ENV{NLS_LANG}x" eq "x") ||
	     ("$ENV{FND_TOP}x" eq "x") ||
	     ("$ENV{AU_TOP}x" eq "x") ||
	     ("$ENV{CONTEXT_FILE}x" eq "x")) {
	  print "ERROR: environment not set. Please source the Applications environment.\n";
	  die "\n";
	}
	$au_top = "$ENV{AU_TOP}";
	$appl_top = "$ENV{APPL_TOP}";
	$fnd_top = "$ENV{FND_TOP}";

	# get args and open log file;
  getArgs();
  # validate args
  validateArgs();
  # before process : check apps/dbschema password;
  #                  change nls_lang charset
  beforeProcess();

  for(my $itype=0; $itype<@_type; $itype++){

  	$currentType = $_type[$itype];

    getTypeConfig($currentType);

    validateTypeConfig($currentType);

    getObjectListbyType($currentType,$arg{'listfile'});
    
    if (@_objectList > 0){
	  	printLogAndOut("# -------------------------------------------------\n", 1);
	  	printLogAndOut("# download type: $currentType\n", 1);
	  	printLogAndOut("# -------------------------------------------------\n", 1);
	  	
	  	# log install step config
		  foreach my $typeConfigKey (keys %_typeConfig){
		    printLogAndOut("$typeConfigKey = $_typeConfig{$typeConfigKey}\n", 1);
		  }
      downloadObjects();
    }
  }
  
  afterProcess();
}

# =============================================================================
# populates the directory %arg with OS specific values
# =============================================================================
sub setOSspecifics
{
  # hash containing the key value pairs of different platforms
  my %osname_short_names = (
    'MSWin32'    => 'win32',
    'Windows_NT' => 'win32',
    'linux'      => 'linux',
    'decunix'    => 'decunix',
    'dec_osf'    => 'decunix',
    'hpux'       => 'hpunix',
    'aix'        => 'aix',
    'solaris'    => 'solaris',
    'sunos'      => 'solaris',
  );
	$arg{'osname'} = $osname_short_names{ $Config{osname} };
	
  if ($arg{'osname'} eq 'win32') {
      $arg{'filePathDel'} = "\\";        # "\" for Windows 
      $arg{'classPathDel'} = ";";
  } else {
      $arg{'filePathDel'} = "\/";        # default is "/"
      $arg{'classPathDel'} = ":";
  }
}

# =============================================================================
# validate database rac mode or no 
# =============================================================================
sub validateRac{
	my $two_task;
	$two_task = "$ENV{TWO_TASK}";
	
	if ( $two_task =~ /BALANCE/ ) {
		$rac_mode = "1";
		getVirtualIp();
	}
	else {
		$rac_mode = "";
	}
}


sub getVirtualIp
{
	my $sqlSpoolFile = getOSfilepath("$arg{currentdir}/setup_spoolfile.txt");
	my $scriptsVip = "";
	my $vip ;
	my $hostname = $ctx{'s_dbhost'};
	
  $scriptsVip .= "SET VERIFY OFF;\n";
  $scriptsVip .= "SET TERM OFF;\n";
  $scriptsVip .= "SET HEAD OFF;\n";
  $scriptsVip .= "SET FEEDBACK OFF;\n";
  $scriptsVip .= "SPOOL $sqlSpoolFile\n";
  $scriptsVip .= "SELECT NVL(virtual_ip,host)\n";
  $scriptsVip .= "FROM fnd_nodes\n" ;
  $scriptsVip .= "WHERE host='$hostname';\n" ;
	$scriptsVip .= "SPOOL OFF\n";
	$scriptsVip .= "EXIT;\n";
	
	# run sql script
	my $runStatus = runSqlScript($scriptsVip,"apps",$arg{'appspwd'});
	if( $runStatus != 0 ){
		errorAndExit("ERROR at run sql: $@\n");
	}
	
	# get language list from spool file
	open (SPOOLFILE,"$sqlSpoolFile") || die ("Cannot open $sqlSpoolFile");
  while ($vip=<SPOOLFILE>) 
  {
    chomp ($vip);          # Get rid of the trailling \n
    $vip =~ s/^\s*//;     # Remove spaces at the start of the line
    $vip =~ s/\s*$//;     # Remove spaces at the end of the line
		if ($vip ne ""){
			$ctx{'s_dbhost'} = $vip ;
		}
  }
	close SPOOLFILE || die "ERROR: Can not close file : $sqlSpoolFile";
	# delete spool file
	unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	
	printLogAndOut("virtual_ip:$ctx{'s_dbhost'}\n", 1);

}


# =============================================================================
# get args
# =============================================================================
sub getArgs{
  my $defaultCfgFile;
  my $objectsListFile;
  my $defaultLogFile;

  foreach (@ARGV) {
    s/placepath=//, $arg{'placepath'} = $_, next if (/^placepath=/);
    s/cfgfile=//, $arg{'cfgfile'} = $_, next if (/^cfgfile=/);
    s/listfile=//, $arg{'listfile'} = $_, next if (/^listfile=/);
    s/appsusr=//, $arg{'appsusr'} = $_, next if (/^appsusr=/);
    s/appspwd=//, $arg{'appspwd'} = $_, next if (/^appspwd=/);
    s/contextfile=//, $arg{'contextfile'} = $_, next if (/^contextfile=/);
    s/dbschemapwd=//, $arg{'dbschemapwd'} = $_, next if (/^dbschemapwd=/);
    s/logfile=//, $arg{'logfile'} = $_, next if (/^logfile=/);
    printUsageAndExit();
  }
  
  # prompt user to enter install path
  if(!defined($arg{'placepath'})){
  	$arg{'placepath'} = promptUserEnter("Please enter code place path [$arg{'currentdir'}]: ", $arg{'currentdir'});
  	$arg{'placepath'} = getOSfilepath($arg{'placepath'});
  }else{
  	$arg{'placepath'} = getOSfilepath($arg{'placepath'});
  }

  if(!defined($arg{'cfgfile'})){
    $defaultCfgFile = getOSfilepath("$arg{'placepath'}/downloadconf/download.cfg"); 	
    if( ! -f "$defaultCfgFile" ){
        $defaultCfgFile = getOSfilepath("$arg{'currentdir'}/download.cfg");
    }
  	$arg{'cfgfile'} = promptUserEnter("Please enter download config file[$defaultCfgFile]: ", $defaultCfgFile);
  	$arg{'cfgfile'} = getOSfilepath($arg{'cfgfile'});
  }else{
  	$arg{'cfgfile'} = getOSfilepath($arg{'cfgfile'});
  }
  
  if(!defined($arg{'listfile'})){
    $objectsListFile = getOSfilepath("$arg{'placepath'}/downloadconf/objectslist.cfg");
    if( ! -f "$objectsListFile" ){
  	  $objectsListFile = getOSfilepath("$arg{'currentdir'}/objectslist.cfg");
    }
  	$arg{'listfile'} = promptUserEnter("Please enter objects list file[$objectsListFile]: ", $objectsListFile);
  	$arg{'listfile'} = getOSfilepath($arg{'listfile'});
  }else{
  	$arg{'listfile'} = getOSfilepath($arg{'listfile'});
  }

  # prompt to enter apps user and password
	if(!defined($arg{'appsusr'}) && !defined($arg{'appspwd'})){
		$arg{'appsusr'} = promptUserEnter("Please enter the APPS User [apps]: ", "apps");
		$arg{'appspwd'} = promptUserEnter("Please enter the APPS password [apps]: ", "apps");
  }
  
  # Set default log file if not defined
	if(!defined($arg{'logfile'})){
	  $defaultLogFile = getOSfilepath("$arg{'currentdir'}/download.log");
	  $arg{'logfile'} = promptUserEnter("Please enter log file[$defaultLogFile]: ", $defaultLogFile);
	  $arg{'logfile'} = getOSfilepath($arg{'logfile'});
  }else{
  	$arg{'logfile'} = getOSfilepath($arg{'logfile'});
  }
  
  # open log file
  if(!open(LOGFH, ">>".$arg{'logfile'})){
    errorAndExit("Open log file ".$arg{'logfile'}.": $!\n");
  }

}

# =============================================================================
# validate args
# =============================================================================
sub validateArgs{
	# check require arg
	if(!defined($arg{'placepath'}) || !defined($arg{'cfgfile'}) || !defined($arg{'listfile'}) || !defined($arg{'appsusr'}) || !defined($arg{'appspwd'})){
    printUsageAndExit();
  }
  # check place path exists
  if( ! -d "$arg{'placepath'}" ){
  	errorAndExit("code place path ".$arg{'placepath'}." is not valid.\n");
  }
  # check download config file exists
  if( ! -f "$arg{'cfgfile'}" ){
  	errorAndExit("Download config file ".$arg{'cfgfile'}." is not valid.\n");
  }
  # check objects list file exists
  if( ! -f "$arg{'listfile'}" ){
  	errorAndExit("Objects list file ".$arg{'listfile'}." is not valid.\n");
  }
  # set default context file
  if(!defined($arg{'contextfile'})){
  	$arg{'contextfile'} = $ENV{CONTEXT_FILE};
  }
  # check context file exists
  if( ! -f "$arg{'contextfile'}" ){
  	errorAndExit("Context file ".$arg{'contextfile'}." is not valid.\n");
  }
  # open context file to get oa value use getCtxValue
  $javaOps = new ADX::util::Java($arg{'contextfile'});
  $util = $javaOps->{util};

}

# =============================================================================
# Print usage and exit
# =============================================================================
sub printUsageAndExit
{
  my $str = shift;
  my $defaultLogFile = getOSfilepath("$arg{'currentdir'}/download.log");
  my $usagestr = <<EOF;
  usage:
  perl download.pl [placepath=<placepath>]
                   [cfgfile=<cfgfile>]
                   [listfile=<listfile>]
                   [appsusr=<appsusername>]
                   [appspwd=<appspassword>]
                   [contextfile=<filename>]
                   [logfile=<filename>]
                   [dbschemapwd=<dbschemapwd>]
  where
    * [placepath=<placepath>]           download code place path
    * [cfgfile=<cfgfile>]               config file
    * [listfile=<listfile>]             download object list file
    * [appsusr=<appsusername>]          apps user name
    * [appspwd=<appspassword>]          apps password
    * [contextfile=<filename>]          context file
    * [logfile=<filename>]              downloader log file name.
                                           default: $defaultLogFile
    * [dbschemapwd=<dbschemapwd>]              cux password
 
EOF
 
  print STDERR $usagestr;
  exit(1);
}

# =============================================================================
# returns string with OS specific path formatting
# =============================================================================
sub getOSfilepath
{
    my $cmd = $_[0];
    $cmd =~ s/\//$arg{'filePathDel'}/g;
    return $cmd;
}

# =============================================================================
# prompt user to enter some word
# =============================================================================
sub promptUserEnter
{
  my $promt= shift;
  my $defaultValue = shift;
  my $userEnter;
  
  print $promt;
  chomp($userEnter=<STDIN>);
  print "\n";
  
  if($userEnter eq ""){ $userEnter = $defaultValue }
  
  return $userEnter;
}

# =============================================================================
# print the string to log file.
# =============================================================================
sub printLogAndOut
{
  my $str= shift;
  my $toOut = shift;
 
  unless(print LOGFH $str) {
    print STDERR "Unable to print to logfile: $!\n";
    exit(1);
  }
 
  if($toOut == 1) {
    unless(print STDOUT $str) {
      print STDERR "Unable to print to stdout: $!\n";
      exit(1);
    }
  }
}

# =============================================================================
# print_banner
# =============================================================================
sub printBanner
{
  print <<END_OF_BANNER;
 +===========================================================================+
 |        Copyright (c) 2011 China Resources (Holdings) Co., Ltd.            |
 |                      All rights reserved                                  |
 |                                                                           |
 |           Oracle Applications extensions rapid download tool              |
 |                                                                           |
 |                $gProgname Version $gProgVersion                              |
 +===========================================================================+

END_OF_BANNER
}

# =============================================================================
# Print the error string and exit
# =============================================================================
sub errorAndExit
{
  my $str = shift;
  printLogAndOut("\nerror:\n  ".$str.
     "\n\nPlease check log file at ".$arg{'logfile'}."\n", 1);
  exit(1);
}

# =============================================================================
# before process
# =============================================================================
sub beforeProcess
{
  # read config file
  readConfigFile($arg{'cfgfile'});

  # get customer dbschema and get dbschema password
  if(!defined($arg{'dbschemapwd'})){
  	$arg{'dbschemapwd'} = promptUserEnter("Please enter the $cfg{'dbschema'} password [$cfg{'dbschema'}]: ", "$cfg{'dbschema'}");
  }

  # check apps password
  validateDBPassword($arg{'appsusr'}, $arg{'appspwd'});

  # check customer application schema password
  validateDBPassword($arg{'dbschema'}, $arg{'dbschemapwd'});
  
  validateRac();
  
  # get applicaton install language
  getInstallLanguage();
  
  # change nls_lang charset
 	if(defined($cfg{'nls_lang_charset'}) && $cfg{'nls_lang_charset'} ne ""){
  	changeNLSCharset($cfg{'nls_lang_charset'});
  }
}

# =============================================================================
# read download config file; log config setup; validate required setups
# =============================================================================
sub readConfigFile {
    my $configFile = $_[0];
    my ($line, $key, $value);
    my $typCount = 0;
    open (FHCONFIG, $configFile) || die "ERROR: Config file not found : $configFile";

    while ($line=<FHCONFIG>) 
    {
      chomp ($line);          # Get rid of the trailling \n
      $line =~ s/^\s*//;     # Remove spaces at the start of the line
      $line =~ s/\s*$//;     # Remove spaces at the end of the line
      if ( ($line !~ /^#/) && ($line ne "") )
      { # Ignore lines starting with # and blank lines
        ($key, $value) = split (/:/, $line);          # Split each line into name value pairs
        $key =~ s/^\s*//;
        $key =~ s/\s*$//;
        $value =~ s/^\s*//;
        $value =~ s/\s*$//;
        
        if($key eq "context"){
          $ctx{$value} = getCtxValue($value,"s",1);
        } elsif($key eq "objecttype"){
        	@_type[$typCount] = $value;
        	$typCount += 1;
        } else{
        	$cfg{$key} = $value;
        }
      }
    }
    close(FHCONFIG) || die "ERROR: Can not close file : $configFile";

  printLogAndOut("context variables:\n", 0);
  foreach my $ctxKey (keys %ctx){
  	printLogAndOut("$ctxKey = $ctx{$ctxKey}\n", 0);
  }
  printLogAndOut("other variables:\n", 0);
  foreach my $cfgKey (sort keys %cfg){
  	printLogAndOut("$cfgKey = $cfg{$cfgKey}\n", 0) unless($cfgKey =~ m/\./);
  }

  # check required setups
  if(!defined($cfg{'dbschema'}) || $cfg{'dbschema'} eq ""){
  	errorAndExit("Config file error: dbschema must be setup.\n");
  }
  if(!defined($cfg{'appshortname'}) || $cfg{'appshortname'} eq ""){
  	errorAndExit("Config file error: appshortname must be setup.\n");
  }
  if(!defined($cfg{'basepath'}) || $cfg{'basepath'} eq ""){
  	errorAndExit("Config file error: basepath must be setup.\n");
  }
  
  # set dbschema from config file
  $arg{'dbschema'} = $cfg{'dbschema'};
  # set install base path
  $basepath = $ENV{$cfg{'basepath'}};
  if($basepath eq ""){
  	errorAndExit("ERROR: $cfg{'basepath'} environment not set. Please source the Applications environment.\n");
  }
  printLogAndOut("download source path : $basepath\n", 0);
  
}

# =============================================================================
# getCtxValue reads and verifies values from the context file
#	
# param search: search string
# param type: d = directory, f = regular file, s = string
# param check: 0 = no verification requested, 1 = do verify and exit in error case
# =============================================================================
sub getCtxValue
{
  my ($search, $type, $check) = @_;
  my $result = "";
  my $ret;
  ($result, $ret) = $util->getCtxValue($search, $type, $check);
  if ($ret !=0 ){
      printLogAndOut( "\nError in getting Context Value for $search \n",1);
  }
  return $result;
}

# =============================================================================
# check db user password
# =============================================================================
sub validateDBPassword
{
  my $dbusr= shift;
  my $dbpwd = shift;
	
	printLogAndOut("check $dbusr passwork ...\n\n", 1);

	# try to login to oracle
	my $sqlResult = `sqlplus -s \/nolog <<EOFSQL;
connect $dbusr/$dbpwd
exit;
EOFSQL`;

	# print result to log
	printLogAndOut($sqlResult, 1);
	
	# exit when check failure
	if ( $sqlResult=~ /Connected/ ){
		printLogAndOut("Check success!\n", 1);
		return;
	}

	errorAndExit("Unable to connect to oracle using $dbusr/$dbpwd.\n");

}

# =============================================================================
# get install language
# =============================================================================
sub getInstallLanguage
{
	my $lang;
	my $langCount = 0;
	my $sqlSpoolFile = getOSfilepath("$arg{currentdir}/install_spoolfile.txt");
	my $langName;
	my $isoLangName;
	my $langEnv;
	
	# get install language sql script
	my $getLanguageSql = getSqlScript("INSTALL_LANGUAGE", $sqlSpoolFile ,"","");
	# run sql script
	my $runStatus = runSqlScript($getLanguageSql);
	if( $runStatus != 0 ){
		errorAndExit("ERROR at run sql: $@\n");
	}
	
	# get language list from spool file
	open (SPOOLFILE,"$sqlSpoolFile") || die ("Cannot open $sqlSpoolFile");
  while ($lang=<SPOOLFILE>) 
  {
    chomp ($lang);          # Get rid of the trailling \n
    $lang =~ s/^\s*//;     # Remove spaces at the start of the line
    $lang =~ s/\s*$//;     # Remove spaces at the end of the line
    if($lang ne ""){
      ($langName, $isoLangName ,$langEnv) = split(/:/, $lang);
      @_lang[$langCount] = $langName;
      $_isoLang{$langName} = $isoLangName;
      $_envLang{$langName} = $langEnv;
      $langCount += 1;
    }
  }
	close SPOOLFILE || die "ERROR: Can not close file : $sqlSpoolFile";
	# delete spool file
	unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	
	# log install language list
	printLogAndOut("--------------------------------------------\n", 1);
	printLogAndOut("- application install languages:\n",1);
	printLogAndOut("--------------------------------------------\n", 1);
	for(my $iLang=0; $iLang<@_lang; $iLang++){
		printLogAndOut("$_lang[$iLang] $_isoLang{$_lang[$iLang]} $_envLang{$_lang[$iLang]}\n", 1);
	}
}

# =============================================================================
# get sql script
# =============================================================================
sub getSqlScript
{
	my $option = $_[0];
	my $spoolFile = $_[1];
	my $object_name = $_[2];
	my $object_type = $_[3];
	my $sqlScript = "";
	
	
	if($option eq "INSTALL_LANGUAGE"){
	  # $sqlScript .= "WHENEVER SQLERROR EXIT FAILURE;\n";
		$sqlScript .= "SET VERIFY OFF;\n";
		$sqlScript .= "SET TERM OFF;\n";
		$sqlScript .= "SET HEAD OFF;\n";
		$sqlScript .= "SET FEEDBACK OFF;\n";
    $sqlScript .= "SPOOL $spoolFile\n";
    
    $sqlScript .= "SELECT LANGUAGE_CODE || ':' || LOWER(ISO_LANGUAGE) || '_' || ISO_TERRITORY || ':' || NLS_LANGUAGE || '_' || NLS_TERRITORY\n";
    $sqlScript .= "  FROM FND_LANGUAGES\n";
    $sqlScript .= " WHERE INSTALLED_FLAG IN ('B','I')\n";
    $sqlScript .= " ORDER BY INSTALLED_FLAG, LANGUAGE_CODE;\n";
    
	  $sqlScript .= "SPOOL OFF\n";
	  $sqlScript .= "EXIT;\n";	  
	}elsif($option eq "DOWNLOAD_SOURCE"){
		$sqlScript .= "SET VERIFY OFF;\n";
		$sqlScript .= "SET TERM OFF;\n";
		$sqlScript .= "SET HEAD OFF;\n";
		$sqlScript .= "SET DEFINE OFF;\n";
		$sqlScript .= "SET WRAP OFF;\n";
		$sqlScript .= "SET LIN 4000;\n";
		$sqlScript .= "SET PAGES 50000;\n";
		$sqlScript .= "SPOOL $spoolFile\n";
		
		$sqlScript .= "SELECT TEXT\n";
		$sqlScript .= "FROM user_source\n";
		$sqlScript .= "WHERE name='$object_name'\n";
		$sqlScript .= "and type='$object_type'\n";
		$sqlScript .= "ORDER BY LINE;\n";
		
		$sqlScript .= "SPOOL OFF\n";
	  $sqlScript .= "EXIT;\n";
	}
	
	return $sqlScript;
}

# =============================================================================
# run sql script: create sql file and run
# =============================================================================
sub runSqlScript
{
	my $sqlScript = $_[0];
	my $sqltempfile = getOSfilepath("$arg{'currentdir'}/install_sqltempfile.sql");
	
	# create sql temp file
	open (SQLTMPFILE,">$sqltempfile") || die ("Cannot open $sqltempfile");
	print SQLTMPFILE $sqlScript;
	close SQLTMPFILE || die "ERROR: Can not close file : $sqltempfile";;
	
	my $retcode = system("sqlplus -s $arg{appsusr}/$arg{appspwd} \@$sqltempfile");
	$retcode = $retcode/256;
	
	# remove the sql temp file whatever may be the status of retcode.
  unlink $sqltempfile if(-f $sqltempfile);

	# return the status of the sql run.
  return $retcode;
}

# =============================================================================
# change nls_lang charset
# =============================================================================
sub changeNLSCharset
{
	my $changeToCharset = $_[0];
	my $nlsLanguage;
	my $nlsCharset;
	
	($nlsLanguage, $nlsCharset) = split (/\./, $ENV{NLS_LANG});
	# change nls_lang
	if($nlsCharset ne $changeToCharset){
		printLogAndOut("changed $ENV{NLS_LANG} to $nlsLanguage.$changeToCharset\n",1);
		$ENV{NLS_LANG} = "$nlsLanguage.$changeToCharset";
	}
  
}

# =============================================================================
# read Type Configs
# =============================================================================
sub getTypeConfig
{
	my $typeName = $_[0];
	my $cfgValue;
	
	undef %_typeConfig;
	# get type config from hashtable:_cfg
  foreach my $cfgKey (sort keys %cfg){
  	$cfgValue = $cfg{$cfgKey};
  	if($cfgKey =~ s/^$typeName\.//i && $cfgKey ne ""){
  		$_typeConfig{lc $cfgKey} = $cfgValue;
  	}
  }

}

# =============================================================================
# validate Type Configs
# =============================================================================
sub validateTypeConfig
{
  # check install step required setup
  if(!defined($_typeConfig{'destdir'}) || $_typeConfig{'destdir'} eq ""){
  	errorAndExit("Config error: $currentType.destdir not defined.\n");
  }
  
  $_typeConfig{'multilanguage'}="N" if(!defined($_typeConfig{'multilanguage'}));
  errorAndExit("Config error: $currentType.sourcedir is invalid.[Y\/N]\n") unless($_typeConfig{'multilanguage'} eq "N" || $_typeConfig{'multilanguage'} eq "Y");
  
}

# =============================================================================
# get objects list by type
# =============================================================================
sub getObjectListbyType
{
		my $type = $_[0];
		my $objectListFile = $_[1];
		my ($line, $key, $value);
		my $objectCount = 0;
		
		undef @_objectList ;
		
		open (FHOBJLIST, $objectListFile) || die "ERROR: Object List file not found : $objectListFile";

    while ($line=<FHOBJLIST>) 
    {
      chomp($line);          # Get rid of the trailling \n
      $line =~ s/^\s*//;     # Remove spaces at the start of the line
      $line =~ s/\s*$//;     # Remove spaces at the end of the line
      if ( ($line !~ /^#/) && ($line ne "") )
      { # Ignore lines starting with # and blank lines
        ($key, $value) = split (/\|/, $line);          # Split each line into name value pairs
        $key =~ s/^\s*//;
        $key =~ s/\s*$//;
        $value =~ s/^\s*//;
        $value =~ s/\s*$//;
        
        if($key eq $type){
        	@_objectList[$objectCount] = $value;
        	$objectCount += 1;
        	
        }
      }
    }
    close(FHOBJLIST) || die "ERROR: Can not close file : $objectListFile";

}

# =============================================================================
# download Objects 
# =============================================================================
sub downloadObjects
{
	my $oldNlsLang = "";
	my $destinationdir = getOSfilepath($arg{'placepath'}."/".$_typeConfig{'destdir'});
	
	if(!-d $destinationdir){
		if(!createDir($destinationdir)){ errorAndExit("Could not create directory: $destinationdir\n");}
	}

	
	# change nls_lang charset
	if(defined($_typeConfig{'charset'}) && $_typeConfig{'charset'} ne ""){
		$oldNlsLang = $ENV{NLS_LANG};
		changeNLSCharset($_typeConfig{'charset'});
	}
  
	if($_typeConfig{'execute'} ne ""){
		executeProgram();
	}
	
	# restore nls_lang charset
	if($oldNlsLang ne ""){
		$ENV{NLS_LANG} = $oldNlsLang;
		printLogAndOut("restore nls_lang to $ENV{NLS_LANG}\n",1);
	}
}

# =============================================================================
# create directory
# =============================================================================
sub createDir
{
	my $dir = $_[0];
	my $statusFlag;
	# mkpath($stageFiledir);
	$statusFlag = $fsys->create( { dirName => $dir, type => TXK::FileSys::DIRECTORY } );
	if($statusFlag eq TXK::Error::FAIL){
		printLogAndOut("Error:\n".$fsys->getError()."\n", 1);
		return 0;
	}
	return 1;
}

# =============================================================================
# execute program
# =============================================================================
sub executeProgram
{
	my $filedirLang;
	my $filedir = getOSfilepath($arg{'placepath'}."/".$_typeConfig{'destdir'});

	if($_typeConfig{'multilanguage'} eq "Y"){
		for(my $iLang=0; $iLang<@_lang; $iLang++){
			$filedirLang = getOSfilepath($filedir."/".$_lang[$iLang]);
			if(!-d $filedirLang){
				if(!createDir($filedirLang)){ errorAndExit("Could not create directory: $filedirLang\n");}
			}
			
			printLogAndOut("in language : $_lang[$iLang]\n",1);
		  
			$currentLang = $_lang[$iLang];
			$currentDir = $filedirLang;
			
			changeNLSLang($_envLang{$currentLang});
			
			if($iLang == 0) {
        $baseLanguageFlag = "Y";
      }else{
        $baseLanguageFlag = "N";
      }
			runProgram();
		}
	}else{
		$currentDir = $filedir;
		$currentLang = "";
		runProgram();
	}
}

# =============================================================================
# change ENV $NLS_LANG
# =============================================================================
sub changeNLSLang
{
	my $changeToLang = $_[0];
	my $nlsLanguage;
	my $nlsCharset;
	
	($nlsLanguage, $nlsCharset) = split (/\./, $ENV{NLS_LANG}); 
	# printLogAndOut("nls language : $nlsLanguage\n",1);
	# printLogAndOut("nls charset  : $nlsCharset\n",1);
	# change nls_lang
	if($nlsLanguage ne $changeToLang){
		printLogAndOut("changed $ENV{NLS_LANG} to $changeToLang.$nlsCharset\n",1);
		$ENV{NLS_LANG} = "$changeToLang.$nlsCharset";
	}
  
  # check whether changed
  # my $result = `echo \$NLS_LANG`;
  # printLogAndOut("NLS_LANG = $result\n",1);
}

# =============================================================================
# run download Program
# =============================================================================
sub runProgram
{
	if($_typeConfig{'execute'} eq "FndXdfGen"){
		runFndXdfGen();
	}elsif($_typeConfig{'execute'} eq "XDOLoader"){
		runXDOLoader();
	}elsif($_typeConfig{'execute'} eq "FNDLOAD"){
		runFNDLOAD();
	}elsif($_typeConfig{'execute'} eq "getobjects"){
		getPlsqlObjects();
	}elsif($_typeConfig{'execute'} eq "CopySource"){
		copySourceCode();
	}elsif($_typeConfig{'execute'} eq "WFLOAD"){
		runWFLOAD();
	}
}

# =============================================================================
# copy source code from stage
# =============================================================================
sub copySourceCode
{
	my $sourceDir = getOSfilepath(eval("\"".$_typeConfig{'sourcedir'}."\""));
	my $sourceFile;
	my $targetFile;
	my $objectowner;
	my $object;
	
	if($_typeConfig{'multilanguage'} eq "Y"){
		$sourceDir = getOSfilepath($sourceDir."/".$currentLang);
	}
	
	for(my $iobject=0; $iobject<@_objectList; $iobject++){
		($objectowner,$object) = split (/\./, $_objectList[$iobject]);
		$sourceFile = getOSfilepath($sourceDir."/".$object.".".$_typeConfig{'extname'});
		$targetFile = getOSfilepath($currentDir."/".$object.".".$_typeConfig{'extname'});
		
		if (!-f $sourceFile){
			printLogAndOut("$sourceFile not exists ,copy incorrupt!\n",1);
		}else{
			printLogAndOut("copy file: $sourceFile to $targetFile\n",1);
			if(!copyFile($sourceFile, $targetFile)){ 
				errorAndExit("Could not copy file: $sourceFile\n"); 
			}
		}
  }
}

# =============================================================================
# get plsql user source
# =============================================================================
sub getPlsqlObjects
{
	my $sqlSpoolFile = getOSfilepath("$arg{currentdir}/download_spoolfile.txt");
	my $objectFile;
	my $getObjectSql;
	my $runStatus;
	my $objectandowner;
	my $object;
	my $objectowner;
	my $line;
	my $lineCount;
	
	#chdir(getOSfilepath($currentDir));
	$object = "";
	for(my $iobject=0; $iobject<@_objectList; $iobject++){

		$objectandowner = $_objectList[$iobject];
		($objectowner,$object) = split (/\./, $objectandowner);
		
	  if (defined($_typeConfig{'defaultappsuser'}) && $_typeConfig{'defaultappsuser'} eq "Y" ) {
	  	$objectowner = $arg{'appsusr'};
	  }
	  
	  if ($objectowner eq "" || $object eq "") {
			printLogAndOut("Error : object and object owner is null\n", 1);
			next;
	  }
		
    $objectFile = getOSfilepath($currentDir."/".$object.".".$_typeConfig{'extname'}) ;
		
		$getObjectSql = getSqlScript("DOWNLOAD_SOURCE", $sqlSpoolFile , $object , $currentType );
		
		unlink $sqlSpoolFile if(-f $sqlSpoolFile);
		
		   printLogAndOut("$getObjectSql\n",1) ;
		
		$runStatus = runSqlScript($getObjectSql);
		if( $runStatus != 0 ){
			printLogAndOut("ERROR at run sql: $@\n",1);
			return;
		}
		
		if(-f $sqlSpoolFile){
		  open (OBJECTFH, ">$objectFile") ||  "ERROR open object file ".$objectFile.": $!\n";
		  open (SPOOLFILE,"$sqlSpoolFile");
		  $lineCount = 0;
		  while ($line=<SPOOLFILE>){
		  	if (rindex($line."\$","\$")>3000){
		  		$lineCount = $lineCount + 1;
		  		$line =~ s/\s*$//;
		  		if ($lineCount == 1) {
		  			$line = "CREATE OR REPLACE ".$line."\n";
		  		}else{
		  			$line .= "\n" ;
		  		}
				  unless(print OBJECTFH $line) {
				    print STDERR "Unable to print to object file: $!\n";
				    exit(1);
				  }
		  	}
		  }
  		unless(print OBJECTFH "/") {
		    print STDERR "Unable to print to object file: $!\n";
		    exit(1);
		  }
		  close SPOOLFILE;
		  close OBJECTFH;
		  unlink $sqlSpoolFile if(-f $sqlSpoolFile);
		}
	}
	
}

# =============================================================================
# run fndload 
# =============================================================================
sub runFNDLOAD
{
	my $objectandowner;
	my $object;
	my $objectowner;
	my $loadScript;
	my $lctFile;
	my $ldtFile;
	my $err;
  my @logFiles;
	my $logEntry;
	my $logFile;
	
	for(my $iobject=0; $iobject<@_objectList; $iobject++){

		$objectandowner = $_objectList[$iobject];
		($objectowner,$object) = split (/\./, $objectandowner);
    
    if ( $object eq "" ){
			printLogAndOut("Error : fndload object is null\n", 1);
			next;
    }
    
		if (defined($_typeConfig{'needapp'}) && $_typeConfig{'needapp'} eq "Y" && $objectowner eq "" ) {
			printLogAndOut("Error : fndload object owner is null\n", 1);
			next;
	  }

		$lctFile = getOSfilepath($_typeConfig{'ctlfile'});
		$ldtFile = getOSfilepath($currentDir."/".$currentType."__".$objectowner."__".$object.".".$_typeConfig{'extname'});
		
		$loadScript = "FNDLOAD $arg{'appsusr'}/$arg{'appspwd'} 0 Y DOWNLOAD";
		$loadScript .= " $lctFile";
		$loadScript .= " $ldtFile";
		$loadScript .= " $_typeConfig{'type'}";
		$loadScript .= " $_typeConfig{'param'}=$object";
		
		if (defined($_typeConfig{'needapp'}) && $_typeConfig{'needapp'} eq "Y" ) {
			$loadScript .= " $_typeConfig{'appparam'}=$objectowner";
		}
		
		if (defined($_typeConfig{'additionclause'}) && $_typeConfig{'additionclause'} ne "" ) {
			$_typeConfig{'additionclause'} =~ s/__/ /;
			$loadScript .= " $_typeConfig{'additionclause'}";
		}
		
		printLogAndOut("$loadScript\n", 1);
		
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				unlink $logFile if(-f $logFile);
			}
		}
		
		$err = runSystemCmd($loadScript);
		
		if($err){
			printLogAndOut("Error run script.\n", 1);
		}
		
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				printLogAndOut("log file $logFile\n\n",1);
				mergeFileToLog($logFile);
				unlink $logFile if(-f $logFile);
			}
		}

	}
}


# =============================================================================
# run wfload
# =============================================================================
sub runWFLOAD
{
	my $objectandowner;
	my $object;
	my $objectowner;
	my $loadScript;
	my $outFile;
	my $err;
  my @logFiles;
	my $logEntry;
	my $logFile;
	
	for(my $iobject=0; $iobject<@_objectList; $iobject++){

		$objectandowner = $_objectList[$iobject];
		($objectowner,$object) = split (/\./, $objectandowner);
    
    if ( $object eq "" ){
			printLogAndOut("Error : $currentType object is null\n", 1);
			next;
    }
    
		if (defined($_typeConfig{'needapp'}) && $_typeConfig{'needapp'} eq "Y" && $objectowner eq "" ) {
			printLogAndOut("Error : $currentType object owner is null\n", 1);
			next;
	  }
	  
		$outFile = getOSfilepath($currentDir."/".$object.".".$_typeConfig{'extname'});
		
		$loadScript = "WFLOAD $arg{'appsusr'}/$arg{'appspwd'} 0 Y DOWNLOAD";
		$loadScript .= " $outFile $object";
		
		
		if (defined($_typeConfig{'additionclause'}) && $_typeConfig{'additionclause'} ne "" ) {
			$_typeConfig{'additionclause'} =~ s/__/ /;
			$loadScript .= " $_typeConfig{'additionclause'}";
		}
		
		printLogAndOut("$loadScript\n", 1);
		
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				unlink $logFile if(-f $logFile);
			}
		}
		
		$err = runSystemCmd($loadScript);
		
		if($err){
			printLogAndOut("Error run script.\n", 1);
		}
		
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				printLogAndOut("log file $logFile\n\n",1);
				mergeFileToLog($logFile);
				unlink $logFile if(-f $logFile);
			}
		}

	}
}


# =============================================================================
# run system command
# =============================================================================
sub runSystemCmd 
{
  my $cmd = $_[0];
  chomp($cmd);
  my $exitValue = 0;
  if (system($cmd) != 0) {
    $exitValue = $? >> 8;
  }

  return $exitValue;
}

# =============================================================================
# copy director list without path
# =============================================================================
sub getDirLists
{
	my ($dirName, $filter, $fileOnly) = @_;
	my @dirList;
	my @excludeList;
	my $entry;
	my $fileName;
	my $iEntry;
	
	chdir($dirName);
	@dirList = glob($filter);
	chdir($arg{'currentdir'});
	if(!$fileOnly){
		return @dirList;
	}
	
	$iEntry = 0;
	foreach $entry (@dirList){
		$fileName = getOSfilepath($dirName."/".$entry);
		if(-f $fileName){
			$excludeList[$iEntry] = $entry;
			$iEntry += 1;
		}
	}
	return @excludeList;
}

# =============================================================================
# merge log File to my Log file
# =============================================================================
sub mergeFileToLog
{
	my $fileName = $_[0];
	my $line;
	
	if(-f $fileName){
		open (FILEHANDLE,"$fileName");
  	while ($line=<FILEHANDLE>){
    	printLogAndOut("$line",0);
  	}
		close FILEHANDLE;
	}
}

# =============================================================================
# create file and director with filter
# =============================================================================
sub copyFileAndDir
{
	my ($srcDir, $dstDir, $filter, $fileMode) = @_;

	my $entry;
	my $source;
	my $target;
	# my @fileList = $fsys->getDirList({ dirName => $srcDir });
	
	my @fileList = getDirLists($srcDir, $filter, 0);
	foreach $entry (@fileList){
		$source = getOSfilepath($srcDir."/".$entry);
		$target = getOSfilepath($dstDir."/".$entry);
		if(-d $source){
			# copy directory
			printLogAndOut("copy dir: $source to $target\n",1);
			if(!-d $target){
				if(!createDir($target)){ errorAndExit("Could not create directory: $target\n");}
			}
			if(!copyDir($source, $target)){ errorAndExit("Could not copy directory: $entry\n"); }
			
			# change file mode
			if($fileMode ne ""){
				chmod(oct($fileMode), $target);
			}
		}elsif(-f $source){
			# copy file
			printLogAndOut("copy file: $source to $target\n",1);
			if(!copyFile($source, $target)){ errorAndExit("Could not copy file: $entry\n"); }
			
			# change file mode
			if($fileMode ne ""){
				chmod(oct($fileMode), $target);
			}
		}
	}
}

# =============================================================================
# copy director
# =============================================================================
sub copyDir
{
	my ($source, $target) = @_;
	my $statusFlag;
	
	$statusFlag = $fsys->copydir( { source => "$source", dest => "$target", recursive => TXK::Util::TRUE } );
	if($statusFlag eq TXK::Error::FAIL){
		printLogAndOut("Error:\n".$fsys->getError()."\n", 1);
		return 0;
	}
	return 1;
}

# =============================================================================
# copy file
# =============================================================================
sub copyFile
{
	my ($source, $target) = @_;
	my $statusFlag;
	
	$statusFlag = $fsys->copy( { source => "$source", dest => "$target" } );
	if($statusFlag eq TXK::Error::FAIL){
		printLogAndOut("Error:\n".$fsys->getError()."\n", 1);
		return 0;
	}
	return 1;
}

# =============================================================================
# run xdf generator
# =============================================================================
sub runFndXdfGen
{
	my $xdfLogFile = getOSfilepath("$arg{currentdir}/download_xdf.log");
	my $objectandowner;
	my $object;
	my $objectowner;
	my $cmpScript;
	my $err;
	my $xsl;
	my $line;
	
	chdir(getOSfilepath($currentDir));
	for(my $iobject=0; $iobject<@_objectList; $iobject++){
		$objectandowner = $_objectList[$iobject];
		($objectowner,$object) = split (/\./, $objectandowner);
	  if (defined($_typeConfig{'defaultappsuser'}) && $_typeConfig{'defaultappsuser'} eq "Y" ) {
	  	$objectowner = $arg{'appsusr'};
	  }
	  
	  if ($objectowner eq "" || $object eq "") {
			printLogAndOut("Error : object and object owner is null\n", 1);
			next;
	  }
	  
	  $xsl = getOSfilepath("$fnd_top/patch/115/xdf/xsl");
  	
  	$cmpScript = "java oracle.apps.fnd.odf2.FndXdfGen";
  	$cmpScript .= " apps_schema=$arg{'appsusr'} apps_pwd=$arg{'appspwd'}";
  	$cmpScript .= " jdbc_protocol=thin jdbc_conn_string=$ctx{'s_dbhost'}.$ctx{'s_dbdomain'}:$ctx{s_dbport}:$ctx{s_dbSid}$rac_mode";
  	$cmpScript .= " object_name=$object xsl_directory=$xsl";
  	$cmpScript .= " owner_app_shortname=$objectowner object_type=$currentType";
  	$cmpScript .= " logfile=$xdfLogFile";
  	printLogAndOut("$cmpScript\n", 1);
  	unlink $xdfLogFile if(-f $xdfLogFile);
  	$err = runSystemCmd($cmpScript);
		if($err){
			printLogAndOut("Error run script.\n", 1);
		}
		
		#merge xdfLogFile into log
		if(-f $xdfLogFile){
			open (XDFLOGFILE,"$xdfLogFile");
		  while ($line=<XDFLOGFILE>){
		    printLogAndOut("$line",0);
		  }
			close XDFLOGFILE;
			
			# delete log file
			unlink $xdfLogFile if(-f $xdfLogFile);
		}
  }
  
	chdir($arg{'currentdir'});
}

# =============================================================================
# run xdo generator
# =============================================================================
sub runXDOLoader
{
	my $xdoLogFile = getOSfilepath("$arg{currentdir}/download_xdo.log");
	my $objectandowner;
	my $object;
	my $objectowner;
	my $loadScript;
	my $err;
	
  my @logFiles;
	my $logEntry;
	my $logFile;
	
	my @xslFiles;
	my $xslFile;
	my $xslEntry;
	my @drvxFiles;
	my $drvxFile;
	my $drvxEntry;
	
	my $mvscripts;
	my $rtfEntry;
	my $rtfFile;
	my @rtfFiles;
	
	my $lctFile;
	my $ldtFile;
	my $dsdir = getOSfilepath($arg{'placepath'}."/".$_typeConfig{'datasourcedir'})."/".$currentLang;
	
	my $sourceRtf;
	my $destRtf;
	
	my $jdbcConnect = "'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=".$ctx{'s_dbhost'}.".".$ctx{'s_dbdomain'}.")(PORT=".$ctx{s_dbport}."))(CONNECT_DATA=(SID=".$ctx{s_dbSid}.$rac_mode.")))'";
	
	if(!-d $dsdir){
		if(!createDir($dsdir)){ errorAndExit("Could not create directory: $dsdir\n");}
	}
	
	for(my $iobject=0; $iobject<@_objectList; $iobject++){
		$objectandowner = $_objectList[$iobject];
		($objectowner,$object) = split (/\./, $objectandowner);

	  if ($objectowner eq "" || $object eq "") {
			printLogAndOut("Error : object and object owner is null\n", 1);
			next;
	  }

		$lctFile = getOSfilepath($_typeConfig{'ctlfile'}) ;
		$ldtFile = getOSfilepath($dsdir."/"."XDO__".$objectowner."__".$object.".".$_typeConfig{'extname'});
		
		$loadScript = "java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD " ;
		$loadScript .= " -DB_USERNAME $arg{'appsusr'} -DB_PASSWORD $arg{'appspwd'}";
		$loadScript .= " -JDBC_CONNECTION $jdbcConnect";
		$loadScript .= " -APPS_SHORT_NAME $objectowner";
		$loadScript .= " -LCT_FILE $lctFile";
		$loadScript .= " -LDT_FILE $ldtFile";
		$loadScript .= " -DS_CODE $object";
		$loadScript .= " -LOG_FILE $xdoLogFile";
		
		printLogAndOut("$loadScript\n", 1);
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				unlink $logFile if(-f $logFile);
			}
		}
		
		unlink $xdoLogFile if(-f $xdoLogFile);
		
		$err = runSystemCmd($loadScript);
		if($err){
			printLogAndOut("Error run script.\n", 1);
		}

		if(-f $xdoLogFile){
			mergeFileToLog($xdoLogFile);
			unlink $xdoLogFile if(-f $xdoLogFile);
		}

		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				printLogAndOut("log file $logFile\n\n",1);
				mergeFileToLog($logFile);
				unlink $logFile if(-f $logFile);
			}
		}
		
		$sourceRtf = getOSfilepath($arg{currentdir}."/"."TEMPLATE_SOURCE_".$objectowner."_".$object."_".$_isoLang{$currentLang}.".rtf" );
		$destRtf = getOSfilepath($currentDir."/".$object.".rtf");
		foreach $logEntry (@logFiles){
			$mvscripts = "mv $sourceRtf $destRtf";
		}
		
		$err = runSystemCmd($mvscripts);
		if($err){
			printLogAndOut("Error run script.\n", 1);
		}
		
		@xslFiles = getDirLists($arg{currentdir} , "TEMPLATE*.xsl" ,1);
		foreach $xslEntry (@xslFiles){
			if($xslEntry =~ /^TEMPLATE\w+/){
				$xslFile = getOSfilepath($arg{currentdir}."/".$xslEntry);
				unlink $xslFile if(-f $xslFile);
			}
		}
		
		@drvxFiles = getDirLists( $arg{currentdir} , "*.drvx" , 1) ;
		foreach $drvxEntry (@drvxFiles){
			$drvxFile = getOSfilepath($arg{currentdir}."/".$drvxEntry);
			unlink $drvxFile if(-f $drvxFile);
		}
		
		@rtfFiles = getDirLists($arg{currentdir} , "TEMPLATE*.rtf" ,1);
		foreach $rtfEntry (@rtfFiles){
			if($rtfEntry =~ /^TEMPLATE\w+/){
				$rtfFile = getOSfilepath($arg{currentdir}."/".$rtfEntry);
				unlink $rtfFile if(-f $rtfFile);
			}
		}
	}
}

# =============================================================================
# after process
# =============================================================================
sub afterProcess
{
  printLogAndOut("\ndownload complete!\n\nPlease check log file at ".$arg{'logfile'}."\n", 1);

  # close log file
  close(LOGFH);
  
  exit(0);
}

main();