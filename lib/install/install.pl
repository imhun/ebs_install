#
# $Header: install.pl 120.1 2008/05/30 00:00:00 hand noship $
#
# *===========================================================================+
# |  Copyright (c) 2008 Hand Enterprise Solutions Co.,Ltd.                    |
# |                        All rights reserved                                |
# |                       Applications  Division                              |
# +===========================================================================+
# |
# | FILENAME
# |   install.pl
# |
# | DESCRIPTION
# |      This script is used to install customer application
# |
# | PLATFORM
# |   Unix Generic
# |
# | NOTES
# |
# | HISTORY
# |        2008-06-15     jim.lin       creation
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

my $currentStep; 	# current install step
my $currentLang; 	# current install language
my $currentDir; 	# current install director
my $currentFile; 	# current install file
my $baseLanguageFlag;   # base language flag

# +===========================================================================+
# | local variables
# +===========================================================================+
my @_step; # array of install step
my %_stepConfig; 	#hash store install step config
my @_lang; # array of application install language
my %_isoLang; # hash store install iso language
my @_supportProg = ("sqlplus","FndXdfCmp","frmcmp_batch","f60gen",
                   "WFLOAD","fndload","xdoload","xliffload","XMLImporter","cpshell","userdefine");
my $gProgname = "to-be-set";
my $gProgVersion = "12.1.0";
my $gRunTimeString;
# my $perlOps;
my $javaOps;
my $util;
my $fsys;
my $errcnt=0;

# +===========================================================================+
# | Begin Main Code Logic
# +===========================================================================+
sub main{
  $gRunTimeString = strftime "%m%d%H%M", localtime;
  ($gProgname = $0) =~ s,.*[/\\],,;
 
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
  
  # before process : read config file; check apps/dbschema password;
  #                  change nls_lang charset
  beforeProcess();
  
  # begin install step
  for(my $istep=0; $istep<@_step; $istep++){
  	$currentStep = $_step[$istep];

  	
  	# clear step config hashtable
  	undef %_stepConfig;
  	# get install step config
  	getInstallStepConfig($currentStep);
  	
  	my $sourceFiledir = getOSfilepath($arg{'installpath'}."/".$_stepConfig{'sourcedir'});

	if(! -d $sourceFiledir){
		# source file director not found, continue next step.
		#printLogAndOut("source file director : $sourceFiledir not found, skip this step\n",1);
		next;
	};
	
  	printLogAndOut("# -------------------------------------------------\n", 1);
  	printLogAndOut("# install step$istep : $currentStep\n", 1);
  	printLogAndOut("# -------------------------------------------------\n", 1);
	
	 # log install step config
	  foreach my $stConfigKey (keys %_stepConfig){
	    printLogAndOut("$stConfigKey = $_stepConfig{$stConfigKey}\n", 1);
	  }
	  
	  printLogAndOut("source file director : $sourceFiledir\n",1);

	  # validate install step config
	  validateStepConfig();
	  
	  # process install step
	  processInstallStep();
	  
  }
  
  # after process : close log file;
  afterProcess();

}
# +===========================================================================+
# | End Main Code Logic
# +===========================================================================+
 
# +===========================================================================+
# | Begin Subroutine Definitions
# +===========================================================================+

# =============================================================================
# get args
# =============================================================================
sub getArgs{
  my $defaultCfgFile;
  
  foreach (@ARGV) {
    s/installpath=//, $arg{'installpath'} = $_, next if (/^installpath=/);
    s/cfgfile=//, $arg{'cfgfile'} = $_, next if (/^cfgfile=/);
    s/appsusr=//, $arg{'appsusr'} = $_, next if (/^appsusr=/);
    s/appspwd=//, $arg{'appspwd'} = $_, next if (/^appspwd=/);
    s/contextfile=//, $arg{'contextfile'} = $_, next if (/^contextfile=/);
    s/logfile=//, $arg{'logfile'} = $_, next if (/^logfile=/);
    s/dbschemapwd=//, $arg{'dbschemapwd'} = $_, next if (/^dbschemapwd=/);
    printUsageAndExit();
  }

  # prompt user to enter install path
  if(!defined($arg{'installpath'})){
  	$arg{'installpath'} = promptUserEnter("Please enter code's path [$arg{'currentdir'}]: ", $arg{'currentdir'});
  	$arg{'installpath'} = getOSfilepath($arg{'installpath'});
  }

  # prompt user to enter config file
  if(!defined($arg{'cfgfile'})){
  	# $defaultCfgFile = getOSfilepath("$arg{'currentdir'}/install.cfg");
  	# check function install config file exists
        $defaultCfgFile = getOSfilepath("$arg{'installpath'}/installconf/install.cfg"); 	
        if( ! -f "$defaultCfgFile" ){
  	        $defaultCfgFile = getOSfilepath("$arg{'currentdir'}/install.cfg");
        }
  	$arg{'cfgfile'} = promptUserEnter("Please enter install config file[$defaultCfgFile]: ", $defaultCfgFile);
  	$arg{'cfgfile'} = getOSfilepath($arg{'cfgfile'});
  }
  
	# prompt to enter apps user and password
	if(!defined($arg{'appsusr'}) && !defined($arg{'appspwd'})){
		$arg{'appsusr'} = promptUserEnter("Please enter the APPS User [apps]: ", "apps");
		$arg{'appspwd'} = promptUserEnter("Please enter the APPS password [apps]: ", "apps");
  }

	# Set default log file if not defined
	if(!defined($arg{'logfile'})){
	  $arg{'logfile'} = getOSfilepath("$arg{'currentdir'}/install.log");
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
	if(!defined($arg{'installpath'}) || !defined($arg{'cfgfile'}) || !defined($arg{'appsusr'}) || !defined($arg{'appspwd'})){
    printUsageAndExit();
  }
  # check install path exists
  if( ! -d "$arg{'installpath'}" ){
  	errorAndExit("install path ".$arg{'installpath'}." is not valid.\n");
  }
  
  # check install config file exists
  if( ! -f "$arg{'cfgfile'}" ){
  	errorAndExit("Install config file ".$arg{'cfgfile'}." is not valid.\n");
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
  # $perlOps = new ADX::util::Sysutil($arg{'contextfile'});

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
# check apps password
# =============================================================================
sub validateDBPassword
{
  my $dbusr= shift;
  my $dbpwd = shift;
	
	printLogAndOut("check $dbusr password ...\n\n", 1);

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
# read install config file; log config setup; validate required setups
# =============================================================================
sub readConfigFile {
    my $configFile = $_[0];
    my ($line, $key, $value);
    my $insCount = 0;
    open (FHCONFIG, $configFile) || die "ERROR: Config file not found : $configFile";

    while ($line=<FHCONFIG>) 
    {
      chomp ($line);          # Get rid of the trailling \n
      $line =~ s/^\s*//;     # Remove spaces at the start of the line
      $line =~ s/\s*$//;     # Remove spaces at the end of the line
      if ( ($line !~ /^#/) && ($line ne "") )
      { # Ignore lines starting with # and blank lines
        ($key, $value) = split (/ /, $line);          # Split each line into name value pairs
        $key =~ s/^\s*//;
        $key =~ s/\s*$//;
        $value =~ s/^\s*//;
        $value =~ s/\s*$//;
        
				#printLogAndOut("key: $key ,value: $value \n",1);
        if($key eq "context"){
        	
					#printLogAndOut("context: $value \n",1);
          $ctx{$value} = getCtxValue($value,"s",1);
					#printLogAndOut("context value: $ctx{$value}\n",1);
					
        } elsif($key eq "installstep"){
        	@_step[$insCount] = $value;
        	$insCount += 1;
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
  
   if(!defined($cfg{'stagepath'}) || $cfg{'stagepath'} eq ""){
  	errorAndExit("Config file error: stagepath must be setup.\n");
  }
  
  # set dbschema from config file
  
  $arg{'dbschema'} = $cfg{'dbschema'};
  # set install base path
  $basepath = $ENV{$cfg{'basepath'}};
  if($basepath eq ""){
  	errorAndExit("ERROR: $cfg{'basepath'} environment not set. Please source the Applications environment.\n");
  }
  printLogAndOut("install base path : $basepath\n", 0);
  
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
  
  # get applicaton install language
  getInstallLanguage();
  
  # change nls_lang charset
 	if(defined($cfg{'nls_lang_charset'}) && $cfg{'nls_lang_charset'} ne ""){
  	changeNLSCharset($cfg{'nls_lang_charset'});
  }
}

# =============================================================================
# get install step config
# =============================================================================
sub getInstallStepConfig
{
	my $stepName = $_[0];
	my $cfgValue;
	
	# get step config from hashtable:_cfg
  foreach my $cfgKey (sort keys %cfg){
  	$cfgValue = $cfg{$cfgKey};
  	if($cfgKey =~ s/^$stepName\.//i && $cfgKey ne ""){
  		$_stepConfig{lc $cfgKey} = $cfgValue;
  	}
  }
	
}

# =============================================================================
# check whether program is support
# =============================================================================
sub isProgramSupport
{
  my $program = $_[0];
    	
	for(my $i=0; $i<@_supportProg; $i++){
		# printLogAndOut("support : @_supportProg[$i]\n", 1);
		if(@_supportProg[$i] eq $program){
			return 1;
		}
	}
	return 0;
}

# =============================================================================
# validate install step config setup
# =============================================================================
sub validateStepConfig
{
  # check install step required setup
  if(!defined($_stepConfig{'sourcedir'}) || $_stepConfig{'sourcedir'} eq ""){
  	errorAndExit("Config error: $currentStep.sourcedir not defined.\n");
  }
  if(!defined($_stepConfig{'filter'}) || $_stepConfig{'filter'} eq ""){
  	errorAndExit("Config error: $currentStep.filter not defined.\n");
  }
  $_stepConfig{'multilanguage'}="N" if(!defined($_stepConfig{'multilanguage'}));
  errorAndExit("Config error: $currentStep.sourcedir is invalid.[Y\/N]\n") unless($_stepConfig{'multilanguage'} eq "N" || $_stepConfig{'multilanguage'} eq "Y");
  
  $_stepConfig{'copytodestination'}="N" if(!defined($_stepConfig{'copytodestination'}));
  errorAndExit("Config error: $currentStep.copytodestination is invalid.[Y\/N]\n") unless($_stepConfig{'copytodestination'} eq "N" || $_stepConfig{'copytodestination'} eq "Y");
  
  if($_stepConfig{'copytodestination'} eq "Y"){
  	if(!defined($_stepConfig{'destinationdir'}) || $_stepConfig{'destinationdir'} eq ""){
  	  errorAndExit("Config error: $currentStep.destinationdir not defined.\n");
    }
    if(!defined($_stepConfig{'destinationfilemode'})){
    	$_stepConfig{'destinationfilemode'} = "";
    }
  }else{
  	$_stepConfig{'destinationdir'} = "";
  }
  
  $_stepConfig{'executeprogram'}="" if(!defined($_stepConfig{'executeprogram'}));
  if($_stepConfig{'executeprogram'} ne ""){
  	if(!isProgramSupport($_stepConfig{'executeprogram'})){
  		errorAndExit("Config error: $currentStep.executeprogram ".$_stepConfig{'executeprogram'}." not support.\n");
  	}
  }
  if($_stepConfig{'executeprogram'} eq "userdefine"){
  	if(!defined($_stepConfig{'userdefineexecute'}) || $_stepConfig{'userdefineexecute'} eq ""){
  		errorAndExit("Config error: $currentStep.userdefineexecute not defined.\n");
  	}
  }else{
  	$_stepConfig{'userdefineexecute'} = "";
  }
  
  # check SqlInBatch setup validate
  if($_stepConfig{'executeprogram'} eq "sqlplus"){
  	$_stepConfig{'sqlinbatch'}="N" if(!defined($_stepConfig{'sqlinbatch'}));
  	errorAndExit("Config error: $currentStep.sqlinbatch is invalid.[Y\/N]\n") unless($_stepConfig{'sqlinbatch'} eq "N" || $_stepConfig{'sqlinbatch'} eq "Y");
  }
	
	# check xdoload setup
  if($_stepConfig{'executeprogram'} eq "xdoload"){
  	if(!defined($_stepConfig{'xdolobtype'}) || $_stepConfig{'xdolobtype'} eq ""){
  		errorAndExit("Config error: $currentStep.XdoLobType not defined\n");
  	}
  	errorAndExit("Config error: $currentStep.XdoLobType is invalid.[TEMPLATE\/DATA_TEMPLATE\/XML_SAMPLE]\n")
  	unless($_stepConfig{'xdolobtype'} eq "TEMPLATE" || $_stepConfig{'xdolobtype'} eq "DATA_TEMPLATE" || $_stepConfig{'xdolobtype'} eq "XML_SAMPLE");
  }
  
  # check cpshell setup
  if($_stepConfig{'executeprogram'} eq "cpshell"){
  	if(!defined($_stepConfig{'copytodestination'}) || $_stepConfig{'copytodestination'} ne "Y"){
  		errorAndExit("Config error: $currentStep.CopyToDestination must set to Y\n");
  	}
  }

}

# =============================================================================
# process install step
# =============================================================================
sub processInstallStep
{
	my $sourceFiledir = getOSfilepath($arg{'installpath'}."/".$_stepConfig{'sourcedir'});
	my $oldNlsLang = "";

	#copy to stage
	copySourceToStage();

	# check whether copy to destination
	if($_stepConfig{'copytodestination'} eq "Y"){
		copySourceToDestination();
	}
	
  # change nls_lang charset
 	if(defined($_stepConfig{'nls_lang_charset'}) && $_stepConfig{'nls_lang_charset'} ne ""){
  	$oldNlsLang = $ENV{NLS_LANG};
  	changeNLSCharset($_stepConfig{'nls_lang_charset'});
  }

	# execute program
	if($_stepConfig{'executeprogram'} ne ""){
		executeProgram();
	}
	
	# restore nls_lang charset
	if($oldNlsLang ne ""){
		$ENV{NLS_LANG} = $oldNlsLang;
		printLogAndOut("restore nls_lang to $ENV{NLS_LANG}\n",1);
	}
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
	
	printLogAndOut("runSqlScript retcode:".$retcode."\n",1);
	
	
	# remove the sql temp file whatever may be the status of retcode.
  unlink $sqltempfile if(-f $sqltempfile);

	# return the status of the sql run.
  return $retcode;
}

# =============================================================================
# get sql script
# =============================================================================
sub getSqlScript
{
	my $option = $_[0];
	my $spoolFile = $_[1];
	my $sqlScript = "";
	
	if($option eq "INSTALL_LANGUAGE"){
	  # $sqlScript .= "WHENEVER SQLERROR EXIT FAILURE;\n";
		$sqlScript .= "SET VERIFY OFF;\n";
		$sqlScript .= "SET TERM OFF;\n";
		$sqlScript .= "SET HEAD OFF;\n";
		$sqlScript .= "SET DEFINE OFF;\n";
		$sqlScript .= "SET FEEDBACK OFF;\n";
    $sqlScript .= "SPOOL $spoolFile\n";
    
    $sqlScript .= "SELECT LANGUAGE_CODE || ':' || LOWER(ISO_LANGUAGE) || '_' || ISO_TERRITORY\n";
    $sqlScript .= "  FROM FND_LANGUAGES\n";
    $sqlScript .= " WHERE INSTALLED_FLAG IN ('B','I')\n";
    $sqlScript .= " ORDER BY INSTALLED_FLAG, LANGUAGE_CODE;\n";
    
	  $sqlScript .= "SPOOL OFF\n";
	  $sqlScript .= "EXIT;\n";	  
	}
	
	return $sqlScript;
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
	
	# get install language sql script
	my $getLanguageSql = getSqlScript("INSTALL_LANGUAGE", $sqlSpoolFile);
	# run sql script
	my $runStatus = runSqlScript($getLanguageSql);
	if( $runStatus != 0 ){
		errorAndExit("Error at run sql: $@\n");
	}
	
	# get language list from spool file
	open (SPOOLFILE,"$sqlSpoolFile") || die ("Cannot open $sqlSpoolFile");
  while ($lang=<SPOOLFILE>) 
  {
    chomp ($lang);          # Get rid of the trailling \n
    $lang =~ s/^\s*//;     # Remove spaces at the start of the line
    $lang =~ s/\s*$//;     # Remove spaces at the end of the line
    if($lang ne ""){
      ($langName, $isoLangName) = split(/:/, $lang);
      @_lang[$langCount] = $langName;
      $_isoLang{$langName} = $isoLangName;
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
		printLogAndOut("$_lang[$iLang]\n", 1);
	}
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
	# printLogAndOut("nls language : $nlsLanguage\n",1);
	# printLogAndOut("nls charset  : $nlsCharset\n",1);
	# change nls_lang
	if($nlsCharset ne $changeToCharset){
		printLogAndOut("changed $ENV{NLS_LANG} to $nlsLanguage.$changeToCharset\n",1);
		$ENV{NLS_LANG} = "$nlsLanguage.$changeToCharset";
	}
  
  # check whether changed
  # my $result = `echo \$NLS_LANG`;
  # printLogAndOut("NLS_LANG = $result\n",1);
}

# =============================================================================
# after process
# =============================================================================
sub afterProcess
{
	if ($errcnt>0){		
		printLogAndOut("\ninstall result : error! <".$errcnt."> error occured!\n\nPlease check log file at ".$arg{'logfile'}."\n", 1);
	}
	else 
	{
		printLogAndOut("\ninstall result : success!\n\nPlease check log file at ".$arg{'logfile'}."\n", 1);
	}

  # close log file
  close(LOGFH);
  
  exit(0);
}

# =============================================================================
# merge file to logfile
# =============================================================================
sub mergeFileToLog
{
	my $fileName = $_[0];
	my $line;
	
	if(-f $fileName){
		open (FILEHANDLE,"$fileName");
  	while ($line=<FILEHANDLE>){
    	printLogAndOut("$line\n",0);
  	}
		close FILEHANDLE;
	}
}

# =============================================================================
# print the string to log file.
# =============================================================================
sub printLogAndOut
{
  my $str= shift;
  my $toOut = shift;
  
	if (($str =~ /^ERROR at line/)||($str =~ /^Errors for PACKAGE/)||($str =~ /^Error at run/)||($str =~ /error occurred/)||($str=~ /^Warning: Package/)){
		$errcnt=$errcnt+1;
		$str = "INSTALL_ERROR(".$errcnt.")\n".$str;
	}
	
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
# print the string to screen.
# =============================================================================
sub printOut
{
  my $str= shift;
 
  unless(print STDOUT $str) {
    print STDERR "Unable to print to stdout: $!\n";
    exit(1);
  }
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
# Print usage and exit
# =============================================================================
sub printUsageAndExit
{
  my $str = shift;
  my $defaultLogFile = getOSfilepath("$arg{'currentdir'}/install.log");
  my $usagestr = <<EOF;
  usage:
    perl install.pl installpath=<installpath> cfgfile=<installconfigfile>
                    [appsusr=<appsusername>] [appspwd=<appspassword>]
                    [dbschemapwd=<dbschemapassword>]
                    [contextfile=<filename>]
                    [logfile=<filename>]
  where
    * installpath=<installpath>         install path
    * cfgfile=<installconfigfile>       install config file
    * [appsusr=<appsusername>]          apps user name
    * [appspwd=<appspassword>]          apps password
    * [dbschemapwd=<dbschemapassword>]  password of dbschema in config file
    * [contextfile=<filename>]          context file
    * [logfile=<filename>]              installer log file name.
                                           default: $defaultLogFile
 
EOF
 
  print STDERR $usagestr;
  exit(1);
}

# =============================================================================
# print_banner
# =============================================================================
sub printBanner
{
  print <<END_OF_BANNER;
 *===========================================================================+
 |        Copyright (c) 2008 Hand Enterprise Solutions Co.,Ltd.
 |                      All rights reserved
 |
 |           Oracle Applications extensions rapid install tool
 |
 |                $gProgname Version $gProgVersion
 *===========================================================================+

END_OF_BANNER
}

# =============================================================================
# executes the passed command in the different os environments
# =============================================================================
sub runSystemCmd 
{
  my $cmd = $_[0];
  chomp($cmd);
  my $exitValue = 0;
  if (system($cmd) != 0) {
    $exitValue = $? >> 8;
  }
  
	printLogAndOut("Systemcmd exitValue:".$exitValue."\n",1);
  
  return $exitValue;
}

# =============================================================================
# run command in pipe
# =============================================================================
sub runPipedCmd
{
   my(@paramArr) = @_ ;
   my $retCode;
   my $script;
   my $count;


    if($#paramArr == -1) {
       die ("runPipedCommand must be passed atlease one argument");
   }

   $script = $paramArr[0];
   if($#paramArr == 0) {
      $retCode = runSystemCmd($script);
   }
   else {
      open(cmdPipe, "| $script");
      for ($count=1; $count<=$#paramArr; $count++) {
          print(cmdPipe $paramArr[$count]."\n");
      }
      close(cmdPipe);
      $retCode= $?;
   }
  
   return $retCode;
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
# returns string with OS specific path formatting
# =============================================================================
sub getOSfilepath
{
    my $cmd = $_[0];
    $cmd =~ s/\//$arg{'filePathDel'}/g;
    return $cmd;
}

sub getAppsVersion
{
  my @vers = split('\.', $ctx{'s_apps_version'});
  return $vers[0];
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
      printLogAndOut( "\nError at run in getting Context Value for $search \n",1);
  }
  return $result;
}

# =============================================================================
# create director
# =============================================================================
sub createDir
{
	my $dir = $_[0];
	my $statusFlag;
	# mkpath($stageFiledir);
	$statusFlag = $fsys->create( { dirName => $dir, type => TXK::FileSys::DIRECTORY } );
	if($statusFlag eq TXK::Error::FAIL){
		printLogAndOut("Error at run:\n".$fsys->getError()."\n", 1);
		return 0;
	}
	return 1;
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
		printLogAndOut("Error at run:\n".$fsys->getError()."\n", 1);
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
		printLogAndOut("Error at run:\n".$fsys->getError()."\n", 1);
		return 0;
	}
	return 1;
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
# copy source to stage
# =============================================================================
sub copySourceToStage
{
	my $sourceFiledirLang;
	my $stageFiledirLang;
	my $sourceFiledir = getOSfilepath($arg{'installpath'}."/".$_stepConfig{'sourcedir'});
	my $stageFiledir = eval("\"".$cfg{'stagepath'}."/".$_stepConfig{'sourcedir'}."\"");
	errorAndExit("eval error : ".$@."\n",1) if ($@); 
	
	$stageFiledir = getOSfilepath($stageFiledir);
	printLogAndOut("begin copy source file to stage: $stageFiledir\n",1);
	if(! -d $stageFiledir){
		if(!createDir($stageFiledir)){ errorAndExit("Could not create directory: $stageFiledir\n");}
	}
	if($_stepConfig{'multilanguage'} eq "Y"){
		for(my $iLang=0; $iLang<@_lang; $iLang++){
			$sourceFiledirLang = getOSfilepath($sourceFiledir."/".$_lang[$iLang]);
			$stageFiledirLang = getOSfilepath($stageFiledir."/".$_lang[$iLang]);
			# skip not current language director
			next if(! -d $sourceFiledirLang);
			
			if(!-d $stageFiledirLang){
				if(!createDir($stageFiledirLang)){ errorAndExit("Could not create directory: $stageFiledirLang\n");}
			}
			copyFileAndDir($sourceFiledirLang, $stageFiledirLang, $_stepConfig{'filter'}, "");
		}
	}else{
		copyFileAndDir($sourceFiledir, $stageFiledir, $_stepConfig{'filter'}, "");
	}
}

# =============================================================================
# copy source to destination
# =============================================================================
sub copySourceToDestination
{
	my $sourceFiledirLang;
	my $destFiledirLang;
	my $sourceFiledir = getOSfilepath($arg{'installpath'}."/".$_stepConfig{'sourcedir'});
	my $destFiledir = eval("\"".$_stepConfig{'destinationdir'}."\"");
	errorAndExit("eval error : ".$@."\n",1) if ($@);
	
	$destFiledir = getOSfilepath($destFiledir);
	printLogAndOut("begin copy source file to destination: $destFiledir\n",1);
	if(! -d $destFiledir){
		if(!createDir($destFiledir)){ errorAndExit("Could not create directory: $destFiledir\n");}
	}
	if($_stepConfig{'multilanguage'} eq "Y"){
		for(my $iLang=0; $iLang<@_lang; $iLang++){
			$sourceFiledirLang = getOSfilepath($sourceFiledir."/".$_lang[$iLang]);
			$destFiledirLang = getOSfilepath($destFiledir."/".$_lang[$iLang]);
			# skip not current language director
			next if(! -d $sourceFiledirLang);
			
			printLogAndOut("in language : $_lang[$iLang]\n",1);
			if(!-d $destFiledirLang){
				if(!createDir($destFiledirLang)){ errorAndExit("Could not create directory: $destFiledirLang\n");}
			}
			copyFileAndDir($sourceFiledirLang, $destFiledirLang, $_stepConfig{'filter'}, $_stepConfig{'destinationfilemode'});
		}
	}else{
		copyFileAndDir($sourceFiledir, $destFiledir, $_stepConfig{'filter'}, $_stepConfig{'destinationfilemode'});
	}
}

# =============================================================================
# run sql file
# =============================================================================
sub runSqlFile
{
	my $sqlFile = $_[0];
	my $line;
	my $sqlSpoolFile = getOSfilepath("$arg{currentdir}/install_spoolfile.txt");
	my $sqlScript = "";

  # $sqlScript .= "WHENEVER SQLERROR EXIT FAILURE;\n";
	$sqlScript .= "SET VERIFY OFF;\n";
	$sqlScript .= "SET TERM OFF;\n";
	$sqlScript .= "SET HEAD OFF;\n";
	$sqlScript .= "SET DEFINE OFF;\n";
	# $sqlScript .= "SET FEEDBACK OFF;\n";
  $sqlScript .= "SPOOL $sqlSpoolFile\n";
  
  $sqlScript .= "prompt run $sqlFile;\n";
  $sqlScript .= "\@$sqlFile;\n";
  
  if($currentStep =~ /^package/){	
  	$sqlScript .= "SHOW ERROR\n";
	}
	
  $sqlScript .= "SPOOL OFF\n";
  $sqlScript .= "EXIT;\n";	  

	#delete spool file first
	unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	
	my $runStatus = runSqlScript($sqlScript);
	if( $runStatus != 0 ){
		printLogAndOut("Error at run sql: $@\n",1);
		return;
	}
	
	#merge spoolfile into log
	if(-f $sqlSpoolFile){
		open (SPOOLFILE,"$sqlSpoolFile");
	  while ($line=<SPOOLFILE>){
	    $line =~ s/^\s*//;     # Remove spaces at the start of the line
	    $line =~ s/\s*$//;     # Remove spaces at the end of the line
	    printLogAndOut("$line\n",1) if($line ne "");
	  }
		close SPOOLFILE;
		
		# delete spool file
		unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	}
}

# =============================================================================
# run sql file in dir with filter
# =============================================================================
sub runSqlplus
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	# my $retcode;
	my @fileList = getDirLists($dirName, $filter, 0);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		# printLogAndOut("sqlplus : $fileName\n",1);
		runSqlFile($fileName);
	}
}

# =============================================================================
# run sql file in dir with filter(batch mode)
# =============================================================================
sub runSqlplusBatch
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $line;
	my $sqlSpoolFile = getOSfilepath("$arg{currentdir}/install_spoolfile.txt");
	my $sqlScript = "";
  # $sqlScript .= "WHENEVER SQLERROR EXIT FAILURE;\n";
	$sqlScript .= "SET VERIFY OFF;\n";
	$sqlScript .= "SET TERM OFF;\n";
	$sqlScript .= "SET HEAD OFF;\n";
	$sqlScript .= "SET DEFINE OFF;\n";
	# $sqlScript .= "SET FEEDBACK OFF;\n";
  $sqlScript .= "SPOOL $sqlSpoolFile\n";
  
	my @fileList = getDirLists($dirName, $filter, 0);
	my $fileCount = 0;
	
	foreach $entry (@fileList){
		$fileCount += 1;
		$fileName = getOSfilepath($dirName."/".$entry);
	  $sqlScript .= "prompt run $fileName;\n";
	  $sqlScript .= "\@$fileName;\n";
	  
	  if($currentStep =~ /^package/){	
	  	$sqlScript .= "SHOW ERROR\n";
		}
	
	}
  $sqlScript .= "SPOOL OFF\n";
  $sqlScript .= "EXIT;\n";
  
  return if($fileCount <= 0);
  
  #delete spool file first
	unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	
	my $runStatus = runSqlScript($sqlScript);
	if( $runStatus != 0 ){
		printLogAndOut("Error at run sql: $@\n",1);
		return;
	}
	
	#merge spoolfile into log
	if(-f $sqlSpoolFile){
		open (SPOOLFILE,"$sqlSpoolFile");
	  while ($line=<SPOOLFILE>){
	    $line =~ s/^\s*//;     # Remove spaces at the start of the line
	    $line =~ s/\s*$//;     # Remove spaces at the end of the line
	    printLogAndOut("$line\n",1) if($line ne "");
	  }
		close SPOOLFILE;
		
		# delete spool file
		unlink $sqlSpoolFile if(-f $sqlSpoolFile);
	}
}

# =============================================================================
# get xdf file infomation:
#     Primary Object Schema Name
#     Primary Object Name
#     Primary Object Type
# =============================================================================
sub getXdfInfo
{
	my $xdfFile = $_[0];
	my $beginFetch = 0;
	my $endFetch = 0;
	my %xdfInfo;
	my $line;
	
	$xdfInfo{'objectSchemaName'} = "";
	$xdfInfo{'objectName'} = "";
	$xdfInfo{'objectType'} = "";
	$xdfInfo{'includeSequence'} = 0;
	
	open (XDFHANDLE,"$xdfFile");
  while ($line=<XDFHANDLE>){
    if (!$beginFetch && $line =~ /^Primary Object\'s Application Short Name/){
    	$beginFetch = 1;
    }
    if($beginFetch){
    	# printLogAndOut("line: $line\n",1);
    	
    	if($line =~ /^Primary Object Schema Name/){
    		$line=<XDFHANDLE>;
    		$line =~ s/^\s*//;     # Remove spaces at the start of the line
    		$line =~ s/\s*$//;     # Remove spaces at the end of the line
    		$xdfInfo{'objectSchemaName'} = $line;
    	}elsif($line =~ /^Primary Object Name/){
    		$line=<XDFHANDLE>;
    		$line =~ s/^\s*//;     # Remove spaces at the start of the line
    		$line =~ s/\s*$//;     # Remove spaces at the end of the line
    		$xdfInfo{'objectName'} = $line;
    	}elsif($line =~ /^Primary Object Type/){
    		$line=<XDFHANDLE>;
    		$line =~ s/^\s*//;     # Remove spaces at the start of the line
    		$line =~ s/\s*$//;     # Remove spaces at the end of the line
    		$xdfInfo{'objectType'} = $line;
    	}elsif($line =~ /^Sequence/){
    		$xdfInfo{'includeSequence'} = 1;
    	}

    	if($line =~ /^-->/){
    		$endFetch = 1;
    	}
    }
    last if($endFetch);
  }
	close XDFHANDLE;
	
	return %xdfInfo;
}

# =============================================================================
# run xdf file in dir with filter
# =============================================================================
sub runFndXdfcmp
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my %xdfInfo;
	my $xdfLogFile = getOSfilepath("$arg{currentdir}/install_xdf.log");
	my $cmpScript;
	my $line;
	my $err;
	my $xslDir = getOSfilepath("$fnd_top/patch/115/xdf/xsl");
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin load xdf file: $fileName\n",1);
		%xdfInfo = getXdfInfo($fileName);
		
		printLogAndOut("schema : $xdfInfo{'objectSchemaName'} name : $xdfInfo{'objectName'} type : $xdfInfo{'objectType'}\n",1);
		if($xdfInfo{'objectSchemaName'} eq "" || $xdfInfo{'objectName'} eq "" ||$xdfInfo{'objectType'} eq "" ){
			printLogAndOut("Error at run getXdfInfo : can not get xdf information\n", 1);
			next;
		}
		
		# check schema whether equals install dbschema
		# if($xdfInfo{'objectSchemaName'} ne $arg{'dbschema'}){
		# 	printLogAndOut("Error : xdf required schema not equals install dbschema\n", 1);
		# 	next;
		# }
		
		printLogAndOut("load $xdfInfo{'objectType'} : $xdfInfo{'objectName'}\n", 1);
		# FndXdfCmp schema_Pwd not use???
		$cmpScript = "adjava oracle.apps.fnd.odf2.FndXdfCmp";
		$cmpScript .= " $xdfInfo{'objectSchemaName'} $xdfInfo{'objectSchemaName'}";
		$cmpScript .= " $arg{'appsusr'} $arg{'appspwd'}";
		$cmpScript .= " thin $ctx{'s_dbhost'}.$ctx{'s_dbdomain'}:$ctx{s_dbport}:$ctx{s_dbSid}";
		$cmpScript .= " all $fileName $xslDir";
		$cmpScript .= " logfile=$xdfLogFile";
		printLogAndOut("$cmpScript\n", 1);
		
		# delete log file
		unlink $xdfLogFile if(-f $xdfLogFile);
		
		# run command
		$err = runSystemCmd($cmpScript);
		# $err = $perlOps->runPipedCmd($cmpScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run FndXdfcmp.\n", 1);
		}

		#merge xdfLogFile into log
		if(-f $xdfLogFile){
			open (XDFLOGFILE,"$xdfLogFile");
		  while ($line=<XDFLOGFILE>){
		    printLogAndOut("$line\n",0);
		  }
			close XDFLOGFILE;
			
			# delete log file
			unlink $xdfLogFile if(-f $xdfLogFile);
		}
	}
}


# =============================================================================
# run form compile script
# =============================================================================
sub runFrmcmpBatch
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $logFile = getOSfilepath("$arg{currentdir}/install_f60gen.log");
	my $cmdScript;
	my $line;
	my $err;
	my $outFileDir;
	my $outFile;
	my $moduleType;
	my $lastLine;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin compile file: $fileName\n",1);
		
		if($entry =~ /\.fmb$/){
			# form file
			$moduleType = "FORM";
			$outFile = $entry;
			$outFile =~s/\.fmb$/.fmx/;
			$outFile = getOSfilepath($basepath."/forms/".$currentLang."/".$outFile);

			# check output file dir exists
			$outFileDir = getOSfilepath($basepath."/forms/".$currentLang);
			if(!-d $outFileDir){
				if(!createDir($outFileDir)){ errorAndExit("Could not create directory: $outFileDir\n");}
			}
		}elsif($entry =~ /\.pll$/){
			# resource
			$moduleType = "LIBRARY";
			$outFile = $entry;
			$outFile =~s/\.pll$/.plx/;
			$outFile = getOSfilepath($au_top."/resource/".$outFile);
		}else{
			printLogAndOut("not a form/library file\n",1);
			next;
		}
			
	  if(getAppsVersion() eq '12'){
	    $cmdScript = "frmcmp_batch";
	  } else {
	    $cmdScript = "f60gen";
	  }
		
		$cmdScript .= " Module=$fileName";
		$cmdScript .= " Userid=$arg{'appsusr'}/$arg{'appspwd'}";
		$cmdScript .= " Module_Type=$moduleType";
		$cmdScript .= " Output_File=$outFile";
		$cmdScript .= " > $logFile";
		
		printLogAndOut("$cmdScript\n", 1);
		
		# delete log file
		unlink $logFile if(-f $logFile);
		
		# run command
		if($moduleType eq "LIBRARY"){
			chdir(getOSfilepath("$au_top/resource"));
		}elsif($moduleType eq "FORM"){
			chdir(getOSfilepath("$au_top/forms/$currentLang"));
		}
		$err = runSystemCmd($cmdScript);
  	chdir($arg{'currentdir'});
		#$err = $perlOps->runPipedCmd($cmdScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run frmcmp_batch\n", 1);
		}

		#merge logFile into log
		if(-f $logFile){
			open (LOGFILE,"$logFile");
		  while ($line=<LOGFILE>){
		    printLogAndOut("$line\n",0);
		    $lastLine = $line;
		  }
			close LOGFILE;
			
			# delete log file
			unlink $logFile if(-f $logFile);
		}

		# print last line to screen
		printOut("\n\n$lastLine\n\n", 1);
	}
}

# =============================================================================
# get ldt file infomation:
# dbdrv: exec fnd bin UPLOAD ...
# LANGUAGE
# LDRCONFIG
# =============================================================================
sub getFndloadInfo
{
	my $ldtFile = $_[0];
	my %ldtInfo;
	my $line;
	my $firstAt;
	my $secondAt;
	
	$ldtInfo{'LANGUAGE'} = "";
	$ldtInfo{'LDRCONFIG'} = "";
	
	open (LDTHANDLE,"$ldtFile");
  while ($line=<LDTHANDLE>){
    last if($line =~ /^# -- Begin Entity Definitions --/);
    
    if($line =~ /^# dbdrv:/){
    	$firstAt = index($line,"@");
    	$secondAt = index($line,"@",$firstAt+1);
    	if($firstAt > 0 && $secondAt > 0){
    		$ldtInfo{'LDRCONFIG'} = substr($line, $firstAt + 1, $secondAt - $firstAt - 1);
    		$ldtInfo{'LDRCONFIG'} =~ s/\s*$//;
    	}
    }elsif($line =~ /^LANGUAGE =/){
    	$line =~ s/LANGUAGE =//;
   		$line =~ s/^\s*//;     # Remove spaces at the start of the line
   		$line =~ s/\s*$//;     # Remove spaces at the end of the line
   		$line =~ s/^\"//;     # Remove spaces at the start of the line
   		$line =~ s/\"$//;     # Remove spaces at the end of the line
    	$ldtInfo{'LANGUAGE'} = $line;
    }
  }
	close LDTHANDLE;
	
	return %ldtInfo;
}

# =============================================================================
# run fndload script
# =============================================================================
sub runFndload
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my %ldtInfo;
	my $lctTop;
	my $lctFile;
	my $ldtLogFile = getOSfilepath("$arg{currentdir}/install_ldt.log");
	my $loadScript;
	my $line;
	my $err;
	my @logFiles;
	my $logEntry;
	my $logFile;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin fndload ldt file: $fileName\n",1);
		%ldtInfo = getFndloadInfo($fileName);
		
		printLogAndOut("ldr config : $ldtInfo{'LDRCONFIG'} language : $ldtInfo{'LANGUAGE'}\n",1);
		if($ldtInfo{'LDRCONFIG'} eq "" || $ldtInfo{'LANGUAGE'} eq "" ){
			printLogAndOut("Error at run getFndloadInfo : can not get ldt file information\n", 1);
			next;
		}
		if(! $ldtInfo{'LDRCONFIG'} =~ /\.lct$/){
			printLogAndOut("Error at run getFndloadInfo : can not get ldt file information\n", 1);
			next;
		}
		
		($lctTop,$lctFile) = split(/:/, $ldtInfo{'LDRCONFIG'});
		if($lctTop eq "" || $lctFile eq ""){
			printLogAndOut("Error at run Fndload : can not get ldt file information\n", 1);
			next;
		}
		$lctFile = getOSfilepath("\$".$lctTop."_TOP/".$lctFile);
		
		$loadScript = "FNDLOAD";
		$loadScript .= " $arg{'appsusr'}/$arg{'appspwd'}";
		$loadScript .= " 0 Y UPLOAD";
		$loadScript .= " $lctFile";
		$loadScript .= " $fileName";
		
		# add multilanguage 
		if ( $baseLanguageFlag eq "N" ){
	             $loadScript .= " UPLOAD_MODE='NLS'";
		}
		
		# add multilanguage 
		$loadScript .= " CUSTOM_MODE='FORCE'";
		
		# $loadScript .= " > $ldtLogFile";
		printLogAndOut("$loadScript\n", 1);

		# delete fndload log file
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				unlink $logFile if(-f $logFile);
			}
		}
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run Fndload.\n", 1);
		}

		#get fndload log file
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
# run wfload script
# =============================================================================
sub runWFload
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $wfLogFile = getOSfilepath("$arg{currentdir}/install_workflow.log");
	my $loadScript;
	my $line;
	my $err;
	my @logFiles;
	my $logEntry;
	my $logFile;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin wfload file: $fileName\n",1);

		$loadScript = "WFLOAD";
		$loadScript .= " $arg{'appsusr'}/$arg{'appspwd'}";
		$loadScript .= " 0 Y UPLOAD";
		$loadScript .= " $fileName";
		$loadScript .= " > $wfLogFile";
		printLogAndOut("$loadScript\n", 1);

		# delete log file
		unlink $wfLogFile if(-f $wfLogFile);
		# delete wfload log file
		@logFiles = getDirLists($arg{currentdir}, "L*.log", 1);
		foreach $logEntry (@logFiles){
			if($logEntry =~ /^L\d+/){
				$logFile = getOSfilepath($arg{currentdir}."/".$logEntry);
				unlink $logFile if(-f $logFile);
			}
		}
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run WFload.\n", 1);
		}

		#merge wfLogFile into log
		if(-f $wfLogFile){
			open (LOGFILE,"$wfLogFile");
		  while ($line=<LOGFILE>){
		    printLogAndOut("$line\n",1);
		  }
			close LOGFILE;
			
			# delete log file
			unlink $wfLogFile if(-f $wfLogFile);
		}

		#merge wfload generate log file
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
# run xodload script
# =============================================================================
sub runXdoload
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $xdoLogFile = getOSfilepath("$arg{currentdir}/install_xdo.log");
	my $loadScript;
	my $line;
	my $err;
	my $fileExt;
	my $filePre;
	my $langName;
	my $isoLanguage;
	my $isoTerritory;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin xdoload file: $fileName\n",1);
		
		if(rindex($entry,".") > 0){
			$filePre = substr($entry, 0, rindex($entry,"."));
			$fileExt = substr($entry, rindex($entry,".")+1);
		}else{
			$filePre = $entry;
		}
		$filePre = uc $filePre;
		$fileExt = uc $fileExt;
		if($_stepConfig{'xdolobtype'} eq "TEMPLATE" && $fileExt eq ""){
			printLogAndOut("Error at run Xdoload : can not get file type: $fileName\n",1);
			next;
		}
		
		if($currentLang eq ""){
			$langName = $_lang[0]; # base install language
		}else{
			$langName = $currentLang;
		}
		
		($isoLanguage,$isoTerritory) = split(/_/, $_isoLang{$langName});

		$loadScript = "java oracle.apps.xdo.oa.util.XDOLoader UPLOAD";
		$loadScript .= " -DB_USERNAME $arg{'appsusr'} -DB_PASSWORD $arg{'appspwd'}";
		$loadScript .= " -JDBC_CONNECTION $ctx{'s_dbhost'}.$ctx{'s_dbdomain'}:$ctx{s_dbport}:$ctx{s_dbSid}";
		$loadScript .= " -LOB_TYPE $_stepConfig{'xdolobtype'}";
		$loadScript .= " -APPS_SHORT_NAME $arg{'dbschema'}";
		$loadScript .= " -LOB_CODE $filePre";
		$loadScript .= " -LANGUAGE $isoLanguage -TERRITORY $isoTerritory";
		if($_stepConfig{'xdolobtype'} eq "DATA_TEMPLATE"){
			$loadScript .= " -XDO_FILE_TYPE XML-DATA-TEMPLATE";
		}elsif($_stepConfig{'xdolobtype'} eq "XML_SAMPLE"){
			$loadScript .= " -XDO_FILE_TYPE XML";
		}elsif($_stepConfig{'xdolobtype'} eq "TEMPLATE"){
			$loadScript .= " -XDO_FILE_TYPE $fileExt";
		}
		
		$loadScript .= " -FILE_NAME $fileName";
		$loadScript .= " -LOG_FILE $xdoLogFile";
		$loadScript .= " -CUSTOM_MODE FORCE";
		printLogAndOut("$loadScript\n", 1);

		# delete xdoload log file
		unlink $xdoLogFile if(-f $xdoLogFile);
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run Xdoload.\n", 1);
		}

		#merge logfile to log
		if(-f $xdoLogFile){
			mergeFileToLog($xdoLogFile);
			unlink $xdoLogFile if(-f $xdoLogFile);
		}
	}
}



# =============================================================================
# run XLIFFLoader script
# =============================================================================
sub runXLIFFLoader
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $xdoLogFile = getOSfilepath("$arg{currentdir}/install_XLIFF.log");
	my $loadScript;
	my $line;
	my $err;
	my $fileExt;
	my $filePre;
	my $langName;
	my $isoLanguage;
	my $isoTerritory;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin XLIFFLoader file: $fileName\n",1);
		
		if(rindex($entry,".") > 0){
			$filePre = substr($entry, 0, rindex($entry,"."));
			$fileExt = substr($entry, rindex($entry,".")+1);
		}else{
			$filePre = $entry;
		}
		$filePre = uc $filePre;
		$fileExt = uc $fileExt;
		if($fileExt eq ""){
			printLogAndOut("Error at run XIFFLoader : can not get file type: $fileName\n",1);
			next;
		}

		$loadScript = "java oracle.apps.xdo.oa.util.XLIFFLoader UPLOAD";
		$loadScript .= " -DB_USERNAME $arg{'appsusr'} -DB_PASSWORD $arg{'appspwd'}";
		$loadScript .= " -JDBC_CONNECTION $ctx{'s_dbhost'}.$ctx{'s_dbdomain'}:$ctx{s_dbport}:$ctx{s_dbSid}";
		$loadScript .= " -APPS_SHORT_NAME $arg{'dbschema'}";
		$loadScript .= " -TEMPLATE_CODE $filePre";
		$loadScript .= " -FILE_NAME $fileName";
		printLogAndOut("$loadScript\n", 1);

		# delete xdoload log file
		unlink $xdoLogFile if(-f $xdoLogFile);
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run XIFFLoader.\n", 1);
		}

		#merge logfile to log
		if(-f $xdoLogFile){
			mergeFileToLog($xdoLogFile);
			unlink $xdoLogFile if(-f $xdoLogFile);
		}
	}
}


# =============================================================================
# check file is OAF page define
# =============================================================================
sub isOAFPageFile
{
	my $xmlFile = $_[0];
	my $isOAFPage = 0;
	my $lineCount = 0;
	my $line;
	
	open (XMLHANDLE,"$xmlFile");
  while ($line=<XMLHANDLE>){
    $lineCount += 1;
    last if($lineCount > 10);
    
    # printLogAndOut("$line\n",1);
    if($line =~ /^<page xmlns:jrad=/ || $line =~ /^<oa:listOfValues/){
    	$isOAFPage = 1;
    	last;
    };
  }
	close XMLHANDLE;
	
	return $isOAFPage;
}

# =============================================================================
# get xmlimport files
# =============================================================================
sub getXmlImportFile
{
	my $dirName = $_[0];
	my @importFiles;
	my @importSubFiles;
	my $entry;
	my $fileOrDir;
	
	my @dirLists = getDirLists($dirName, "*", 0);
	
	# printLogAndOut("in $dirName\n",1);
	
	foreach $entry (@dirLists){
		$fileOrDir = getOSfilepath($dirName."/".$entry);
		if(-d $fileOrDir){
			@importSubFiles = getXmlImportFile($fileOrDir);
			push @importFiles,@importSubFiles if(@importSubFiles > 0);
		}elsif(-f $fileOrDir){
			if($entry =~ /\.xml$/){
				# check file is page file
				push (@importFiles,$fileOrDir) if(isOAFPageFile($fileOrDir));
			}
		}
	}
	return @importFiles;
}

# =============================================================================
# run xmlimport script
# =============================================================================
sub runXmlImport
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $logFile = getOSfilepath("$arg{currentdir}/install_xmlimport.log");
	my $loadScript;
	my $line;
	my $err;
	
	my @fileList = getXmlImportFile($dirName);
	
	foreach $entry (@fileList){
		$fileName = $entry;
		
		printLogAndOut("begin xmlimport file: $fileName\n\n",1);

		$loadScript = "java oracle.jrad.tools.xml.importer.XMLImporter";
		$loadScript .= " $fileName";
		$loadScript .= " -rootdir $dirName";
		$loadScript .= " -username $arg{'appsusr'} -password $arg{'appspwd'}";
		$loadScript .= " -dbconnection \"(description = (address_list = (address = (community = tcp.world)(protocol = tcp)(host = $ctx{'s_dbhost'}.$ctx{'s_dbdomain'})(port = $ctx{s_dbport})))(connect_data = (sid = $ctx{s_dbSid})))\"";
		$loadScript .= " > $logFile";
		printLogAndOut("$loadScript\n", 1);

		# delete xdoload log file
		unlink $logFile if(-f $logFile);
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run XmlImport.\n", 1);
		}

		#merge logfile to log
		if(-f $logFile){
			open (LOGFILE,"$logFile");
		  while ($line=<LOGFILE>){
		    printLogAndOut("$line\n",1);
		  }
			close LOGFILE;

			# delete logfile
			unlink $logFile if(-f $logFile);
		}
	}
}

# =============================================================================
# run cpshell script
# =============================================================================
sub runCPShell
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $fileName;
	my $filePre;
	# my $fileExt;
	my $logFile = getOSfilepath("$arg{currentdir}/install_cpshell.log");
	my $loadScript;
	my $fndcpesrFile;
	my $fndcpesrLink;
	my $line;
	my $err;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	
	foreach $entry (@fileList){
		$fileName = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin cpshell file: $fileName\n",1);
		
		if(rindex($entry,".") > 0){
			$filePre = substr($entry, 0, rindex($entry,"."));
			# $fileExt = substr($entry, rindex($entry,".")+1);
		}else{
			$filePre = $entry;
		}
		$filePre = uc $filePre;
		# $fileExt = uc $fileExt;

		# create link in unix / copy file in win32
		if ($arg{'osname'} eq "win32"){
			$fndcpesrFile = getOSfilepath("$fnd_top/bin/fndcpesr.exe");
			$fndcpesrLink = getOSfilepath("$basepath/bin/$filePre.exe");
			
			printLogAndOut("copy file $fndcpesrFile to $fndcpesrLink\n", 1);
			copyFile($fndcpesrFile, $fndcpesrLink);
		}
		else{
			$fndcpesrFile = getOSfilepath("$fnd_top/bin/fndcpesr");
			$fndcpesrLink = getOSfilepath("$basepath/bin/$filePre");
			
			$loadScript = "ln -s $fndcpesrFile $fndcpesrLink";
			# $loadScript .= " > $logFile";
			printLogAndOut("$loadScript\n", 1);

			# can not get ln log message
			# delete log file
			# unlink $logFile if(-f $logFile);
			
			# run command
			$err = runSystemCmd($loadScript);
			# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
			if($err){
				printLogAndOut("Error at run CPShell : link file $fndcpesrLink.\n", 1);
			}
			
			#merge logfile to log
			# if(-f $logFile){
			# 	mergeFileToLog($logFile);
			#	  unlink $logFile if(-f $logFile);
			# }
		}
	}
}

# =============================================================================
# run userdefine script
# =============================================================================
sub runUserDefine
{
	my ($dirName, $filter) = @_;
	my $entry;
	my $logFile = getOSfilepath("$arg{currentdir}/install_userdefine.log");
	my $loadScript;
	my $line;
	my $err;
	
	my @fileList = getDirLists($dirName, $filter, 1);
	printLogAndOut("$_stepConfig{'userdefineexecute'}\n", 1);
	
	foreach $entry (@fileList){
		$currentFile = getOSfilepath($dirName."/".$entry);
		printLogAndOut("begin userdefine file: $currentFile\n",1);
		
		$loadScript = eval("\"".$_stepConfig{'userdefineexecute'}."\"");
		if ($@){
			printLogAndOut("Error at run  eval error : ".$@."\n", 1);
			next;
		}
		printLogAndOut("$loadScript\n", 1);

		# pipe to logfile
		$loadScript .= " > $logFile";

		# delete log file
		unlink $logFile if(-f $logFile);
		
		# run command
		$err = runSystemCmd($loadScript);
		# $err = $perlOps->runPipedCmd($loadScript,$arg{'appspwd'});
		if($err){
			printLogAndOut("Error at run UserDefine.\n", 1);
		}

		#merge logfile to log
		if(-f $logFile){
			mergeFileToLog($logFile);
			unlink $logFile if(-f $logFile);
		}
	}
}

# =============================================================================
# run program
# =============================================================================
sub runProgram
{
	if($_stepConfig{'executeprogram'} eq "sqlplus"){
		if($_stepConfig{'sqlinbatch'} eq "Y"){
			runSqlplusBatch($currentDir, $_stepConfig{'filter'});
		}else{
		  runSqlplus($currentDir, $_stepConfig{'filter'});
		}
	}elsif($_stepConfig{'executeprogram'} eq "FndXdfCmp"){
		runFndXdfcmp($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "f60gen"){
		runFrmcmpBatch($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "frmcmp_batch"){
		runFrmcmpBatch($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "WFLOAD"){
		runWFload($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "fndload"){
		runFndload($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "xdoload"){
		runXdoload($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "xliffload"){
		runXLIFFLoader($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "XMLImporter"){
		runXmlImport($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "cpshell"){
		runCPShell($currentDir, $_stepConfig{'filter'});
	}elsif($_stepConfig{'executeprogram'} eq "userdefine"){
		runUserDefine($currentDir, $_stepConfig{'filter'});
	}
}

# =============================================================================
# execute program
# =============================================================================
sub executeProgram
{
	my $filedirLang;
	my $filedir = getOSfilepath($arg{'installpath'}."/".$_stepConfig{'sourcedir'});

	if($_stepConfig{'multilanguage'} eq "Y"){
		for(my $iLang=0; $iLang<@_lang; $iLang++){
			$filedirLang = getOSfilepath($filedir."/".$_lang[$iLang]);
			# skip not current language director
			next if(! -d $filedirLang);
			printLogAndOut("in language : $_lang[$iLang]\n",1);
		  
			$currentLang = $_lang[$iLang];
			$currentDir = $filedirLang;
			
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

# +===========================================================================+
# | End Subroutine Definitions
# +===========================================================================+

main();
 