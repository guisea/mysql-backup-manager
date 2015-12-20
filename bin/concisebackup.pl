#! /usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use POSIX qw/strftime/;

my $verbose;
my $backup_dir = '.';
my $ts;
my $db;
my $file;

GetOptions(
    "database=s" => \$db,          # string
    "backup_dir=s" => \$backup_dir, # string
    "verbose"    => \$verbose      # flag
  )                                
  or die("Error in command line arguments\n");

if ( defined($db) ) {
        if ($db ne 'all')
        {
                # Set timestamp
                $ts = strftime( '%Y%m%d%H%M%S', localtime );
                # Backup Database parts;
				backupDb($db);
                # Clean Definer statements and re-assemble
				cleanDefiners();
                print "Backup completed :)\n Filename: $backup_dir/$db-backup-$ts.sql\n";
        }
        else
        {
           my @databases = `mysqlshow | sed '1,/Databases/d'`;
           foreach my $database (@databases){
			 if (defined((split(' ', $database))[1]) 
				  and (split(' ', $database))[1]  ne '')
			 {
				backupDb((split(' ', $database))[1]);
				cleanDefiners();
				print "Backup completed :)\n Filename: $backup_dir/$db-backup-$ts.sql\n";
			 }
           }
        }
    }
else {
    die("Database name was not given");
}

sub backupDb
{
		$db = shift;
	        # dumping out the schema
        print "Writing out the schema!\n";
`mysqldump --no-data --skip-triggers $db > $backup_dir/$db-schema-$ts.sql`;

        # dumping out the data
        print "Writing out the data\n";
`mysqldump --opt --skip-lock-tables --single-transaction --no-create-info --skip-triggers $db > $backup_dir/$db-data-$ts.sql`;
        print "Write out the triggers\n";
        # dumping out the triggers
`mysqldump --no-data --no-create-info $db > $backup_dir/$db-triggers-$ts.sql`;
        print "Write out the routines/functions!\n";
                # dumping out the routines/functiones
`mysqldump --routines --skip-triggers --no-create-info --no-data --no-create-db --skip-opt $db > $backup_dir/$db-funcs-$ts.sql`;

}

sub cleanDefiners {

   # Load file to memory
   loadFile("$backup_dir/$db-triggers-$ts.sql");
   my $altered = $file;
   $altered =~ s/(\/\*!50017 DEFINER=\`\w.*\`@\`.+\`\*\/)//g;
   writeFile( "$backup_dir/$db-triggers-no-definer-$ts.sql", $altered );
   print "Remove definers from triggers\n";
   $altered = '';
   loadFile("$backup_dir/$db-schema-$ts.sql");
   $altered = $file;
   $altered =~ s/(\/\*\!50013.*?\*\/)//g;
   writeFile( "$backup_dir/$db-schema-$ts.sql", $altered );
   print "Remove definers from schema/views\n";
   $altered = '';
   loadFile("$backup_dir/$db-funcs-$ts.sql");
   $altered = $file;
   $altered =~ s/(DEFINER=`.+?`@`.+?`)//g;
   writeFile( "$backup_dir/$db-funcs-$ts.sql", $altered );
   print "Remove definers from functions\n";

   # Disable Foreign Key Checks
   `echo "SET foreign_key_checks = 0;" > $backup_dir/disable-foreign-keys.sql`;

   # Join the dump together again
`cat $backup_dir/disable-foreign-keys.sql $backup_dir/$db-schema-$ts.sql $backup_dir/$db-data-$ts.sql $backup_dir/$db-triggers-no-definer-$ts.sql $backup_dir/$db-funcs-$ts.sql > $backup_dir/$db-backup-$ts.sql`;

   # Remove interim files
`rm -f $backup_dir/$db-schema-$ts.sql $backup_dir/$db-data-$ts.sql $backup_dir/$db-triggers-no-definer-$ts.sql $backup_dir/$db-triggers-$ts.sql $backup_dir/$db-funcs-$ts.sql > /dev/null`;
}


sub loadFile
{
        my $filename = shift;
    open(my $fh, '<', $filename ) or die "cannot open file $filename";
    {
        local $/;
        $file = <$fh>;
    }
    close($fh);
}

sub writeFile
{
        my $filename = shift;
        my $message = shift;
    open(my $fh, '>', $filename ) or die "cannot open file $filename";
        print $fh $message;
    close($fh);
}

