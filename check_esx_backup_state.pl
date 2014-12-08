#!/usr/bin/perl
# icinga: -epn

use Getopt::Long;

$returnstring = "";
$returnstring_no_backup = "";
$returnstring_backup_too_old = "";
$returnvalue = 0;
my @exclude_list = "";
%Flags = "";

sub script_usage {
  print "Usage: $0 -D VCenterserver -u username -p password [-x excludefile]

  -D VCenterserver  VCenter Server IP
  -u username       Username of VCenter
  -p password       Password of VCenter user
  -x excludefile    File with VMs to exclude from the backup check eg. /usr/local/icinga/backup/exclude_list.txt

";

}

sub check_cmdline_options {
  GetOptions('Datacenter|D=s'   => \$Flags{vcenter},
             'username|u=s'    => \$Flags{user},
             'password|p=s'    => \$Flags{passwd},
             'excludefile|x=s'    => \$Flags{file},
             'help|h'       => \$Flags{help},
          )
          or die(script_usage());

  if ($Flags{help}) {
    script_usage();
    exit 0;
  }
  
  if (!$Flags{vcenter}) {
    script_usage();
    print "-D VCenter missing!\n";
    exit 0;
  }
  if (!$Flags{user}) {
    script_usage();
    print "-u username missing!\n";
    exit 0;
  }
  if (!$Flags{passwd}) {
    script_usage();
    print "-p password missing!\n";
    exit 0;
  }
  else {
#    $Flags{passwd} =~ s!\\!!g;
#    $Flags{passwd} =~ s!\@!\\\@!g;
#    $Flags{passwd} =~ s!\\\\!\\!g;
;
  }
  if (!$Flags{file}) {
    $Flags{file} = "/usr/local/icinga/backup/exclude_list.txt";
  }
}


sub gen_excludelist {
  open (EXCLUDE, "$Flags{file}") || die "cannot open $!";
  while (<EXCLUDE>) {
    chomp();
    push (@exclude_list, $_);
  }
  close EXCLUDE;
}

sub exclude_check {
  my $vm_to_check = shift;
  my $ret = 1;

  foreach $vm_in_list (@exclude_list) {
    if ($vm_in_list && $vm_to_check eq $vm_in_list) {
      $ret = 0;
    }
  }
  return $ret;
} 

sub get_backup_state {

  $command = "/usr/bin/perl /usr/lib64/nagios/plugins/check_esx_backup.pl -D " . $Flags{vcenter} . " -u " . $Flags{user} . " -p \"" . $Flags{passwd} . "\" -l runtime -s list";
  open(PROC, "$command |") || die "cannot execute $!";
  while(<PROC>) {
    my @vms = split(/,\s+/);
    foreach $vm (sort @vms) {
      if ($vm =~ /\(UP\)/) { 
        my $pvm = "";
        if ($vm =~ /VMs up:/) {
          $pvm = (split(/VMs up: /, $vm))[1];
          $pvm =~ s/\(UP\)//g;
        }
        elsif ($vm =~ /vmcount/) {
          $pvm = (split(/ \| /, $vm))[0];
          $pvm =~ s/\(UP\)//g;
        }
        else {
          $pvm = $vm;
          $pvm =~ s/\(UP\)//g;
        }
        if (exclude_check($pvm)) {
          $command = "/usr/bin/perl /usr/lib64/nagios/plugins/check_esx_backup.pl -D " . $Flags{vcenter} . " -u " . $Flags{user} . " -p \"" . $Flags{passwd} . "\" -N \"" . $pvm . "\" -l runtime -s backup";
          open(PROC_B, "$command |") || die "cannot execute $!";
          while (<PROC_B>) {
            chomp();
            if (/No Backup/) {
              my $retvalesx = (split(/ \- /, (split(/CHECK_ESX_BACKUP.PL/, $_))[1]))[1];
              my $host = (split(/\"/, $retvalesx))[1];
              $returnstring_no_backup .= "<B>" . $host . "</B> ";
              $returnvalue = 2;
            }
            elsif (/Backup older than 2 days/) {
              my $retvalesx = (split(/ \- /, (split(/CHECK_ESX_BACKUP.PL/, $_))[1]))[1];
              my $host = (split(/\"/, $retvalesx))[1];
              $returnstring_backup_too_old .= "<B>" . $host . "</B> ";
              if ($returnvalue != 2) {
                $returnvalue = 1;
              }
            }
            else {
#              $returnstring .= (split(/ \- /, (split(/CHECK_ESX_BACKUP.PL/, $_))[1]))[1] . ", ";
;
            }
          }
#print $command . "\n";
          close PROC_B;
        }
      }
    }
  }
  close PROC;
}


check_cmdline_options();
gen_excludelist();
get_backup_state();

if ($returnvalue == 0) {
  print "All VM-Backups ok\n";
}
else {
  if ($returnstring_backup_too_old) {
    print "VMs with old Backups: " . $returnstring_backup_too_old;
  }
  if ($returnstring_no_backup) {
    if ($returnstring_backup_too_old) {
      print "<br>\n";
    }
    print "VMs with <B>no</B> Backups: " . $returnstring_no_backup;
  }
  print "\n";
}
exit $returnvalue;
